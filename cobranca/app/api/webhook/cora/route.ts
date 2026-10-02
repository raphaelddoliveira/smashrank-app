import { NextRequest, NextResponse } from 'next/server';
import { consultarCobranca } from '@/lib/cora';
import { rest } from '@/lib/supabase';

export const runtime = 'nodejs';

/**
 * POST /api/webhook/cora
 *
 * A Cora avisa aqui quando a cobrança muda de status. O corpo do webhook NÃO
 * é tratado como verdade: ele diz qual cobrança mexeu, e nós consultamos a
 * API pra confirmar antes de dar qualquer mensalidade como paga.
 */
export async function POST(req: NextRequest) {
  try {
    const segredo = process.env.WEBHOOK_SECRET;
    if (segredo && req.headers.get('x-webhook-secret') !== segredo) {
      return NextResponse.json({ erro: 'não autorizado' }, { status: 401 });
    }

    const evento = (await req.json()) as Record<string, any>;
    const invoiceId: string | undefined =
      evento?.invoice_id ?? evento?.data?.id ?? evento?.id;
    if (!invoiceId) return NextResponse.json({ ok: true, ignorado: 'sem invoice_id' });

    const cobranca = await consultarCobranca(invoiceId);
    const pago = String(cobranca.status).toUpperCase() === 'PAID';
    if (!pago) return NextResponse.json({ ok: true, status: cobranca.status });

    await rest(`/monthly_fees?cora_invoice_id=eq.${invoiceId}`, {
      method: 'PATCH',
      body: {
        status: 'paid',
        paid_at: cobranca.paid_at ?? new Date().toISOString(),
        updated_at: new Date().toISOString(),
      },
      prefer: 'return=minimal',
    });

    return NextResponse.json({ ok: true, baixada: invoiceId });
  } catch (e) {
    console.error('POST /api/webhook/cora', e);
    // 500 faz a Cora reenviar o evento depois — melhor que perder a baixa.
    return NextResponse.json({ erro: 'falha ao processar' }, { status: 500 });
  }
}
