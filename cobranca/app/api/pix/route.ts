import { NextRequest, NextResponse } from 'next/server';
import { randomUUID } from 'node:crypto';
import { criarCobrancaPix } from '@/lib/cora';
import { jogadorDoToken, rest } from '@/lib/supabase';

export const runtime = 'nodejs'; // mTLS não roda no runtime Edge

/**
 * POST /api/pix  { fee_id }
 *
 * Gera o PIX de uma mensalidade EM ABERTO do próprio jogador e devolve o
 * copia-e-cola. Nada é enviado por e-mail ou SMS: a pessoa paga olhando o
 * QR dentro do app.
 */
export async function POST(req: NextRequest) {
  try {
    const token = req.headers.get('authorization')?.replace(/^Bearer /, '');
    if (!token) return NextResponse.json({ erro: 'sem token' }, { status: 401 });

    const jogador = await jogadorDoToken(token);
    if (!jogador) return NextResponse.json({ erro: 'jogador não identificado' }, { status: 401 });

    const { fee_id } = (await req.json()) as { fee_id?: string };
    if (!fee_id) return NextResponse.json({ erro: 'fee_id obrigatório' }, { status: 400 });

    // A mensalidade tem que ser DESTE jogador e estar em aberto.
    const fees = await rest<any[]>(
      `/monthly_fees?select=*&id=eq.${fee_id}&player_id=eq.${jogador.id}&limit=1`,
    );
    const fee = fees[0];
    if (!fee) return NextResponse.json({ erro: 'mensalidade não encontrada' }, { status: 404 });
    if (fee.status === 'paid') {
      return NextResponse.json({ erro: 'esta mensalidade já está paga' }, { status: 409 });
    }

    // Cobrança já gerada antes: devolve a mesma, não cria outra.
    if (fee.cora_invoice_id && fee.pix_code) {
      return NextResponse.json({
        invoice_id: fee.cora_invoice_id,
        pix_code: fee.pix_code,
        valor_centavos: Math.round(Number(fee.amount) * 100),
        vencimento: fee.due_date,
        reaproveitada: true,
      });
    }

    if (!jogador.document) {
      return NextResponse.json(
        { erro: 'cadastre seu CPF no perfil para gerar o PIX' },
        { status: 422 },
      );
    }

    const idempotencyKey = randomUUID();
    const cobranca = await criarCobrancaPix({
      valorCentavos: Math.round(Number(fee.amount) * 100),
      vencimento: String(fee.due_date).slice(0, 10),
      nome: jogador.full_name ?? jogador.nickname ?? 'Associado',
      documento: String(jogador.document).replace(/\D/g, ''),
      email: jogador.email ?? undefined,
      descricao: fee.description ?? 'Mensalidade',
      idempotencyKey,
    });

    await rest(`/monthly_fees?id=eq.${fee_id}`, {
      method: 'PATCH',
      body: {
        cora_invoice_id: cobranca.id,
        pix_code: cobranca.qrCode,
        updated_at: new Date().toISOString(),
      },
      prefer: 'return=minimal',
    });

    return NextResponse.json({
      invoice_id: cobranca.id,
      pix_code: cobranca.qrCode,
      valor_centavos: cobranca.valorCentavos,
      vencimento: cobranca.vencimento,
      reaproveitada: false,
    });
  } catch (e) {
    console.error('POST /api/pix', e);
    return NextResponse.json({ erro: 'falha ao gerar o PIX' }, { status: 500 });
  }
}
