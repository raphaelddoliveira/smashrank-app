import { Header } from '@/components/header'
import { StatCard } from '@/components/stat-card'
import { getPaymentMetrics, getOverduePlayers } from '@/lib/queries/payments'
import { formatCurrency, formatDate } from '@/lib/utils/format'
import { CreditCard, CheckCircle, Clock, AlertTriangle } from 'lucide-react'
import { PaymentCharts } from './payment-charts'
import Link from 'next/link'

export const dynamic = 'force-dynamic'

export default async function PaymentsPage() {
  const [metrics, overdue] = await Promise.all([getPaymentMetrics(), getOverduePlayers()])

  return (
    <>
      <Header title="Mensalidades" subtitle="Controle de pagamentos" />

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <StatCard label="Receita Total" value={formatCurrency(metrics.totalRevenue)} icon={CreditCard} />
        <StatCard label="Pagas" value={metrics.byStatus.paid} icon={CheckCircle} />
        <StatCard label="Pendentes" value={metrics.byStatus.pending} icon={Clock} />
        <StatCard label="Inadimplentes" value={metrics.byStatus.overdue} icon={AlertTriangle} />
      </div>

      <PaymentCharts
        byMonth={metrics.byMonth}
        byStatus={metrics.byStatus}
      />

      {/* Overdue players */}
      {overdue.length > 0 && (
        <div className="bg-white rounded-xl border p-6 mt-6">
          <h3 className="text-base font-semibold text-gray-900 mb-4">
            Jogadores Inadimplentes ({overdue.length})
          </h3>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b bg-gray-50">
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Nome</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Email</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Referencia</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Valor</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Vencimento</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {overdue.map((f: Record<string, unknown>) => {
                  const player = f.player as { id: string; full_name: string; email: string } | null
                  return (
                    <tr key={f.id as string} className="hover:bg-gray-50">
                      <td className="px-4 py-3">
                        <Link
                          href={`/users/${player?.id}`}
                          className="text-blue-600 hover:underline font-medium"
                        >
                          {player?.full_name ?? '-'}
                        </Link>
                      </td>
                      <td className="px-4 py-3 text-gray-600">{player?.email ?? '-'}</td>
                      <td className="px-4 py-3 text-gray-700">
                        {f.reference_month ? formatDate(f.reference_month as string) : '-'}
                      </td>
                      <td className="px-4 py-3 text-gray-700">{formatCurrency(Number(f.amount))}</td>
                      <td className="px-4 py-3 text-red-600 font-medium">
                        {f.due_date ? formatDate(f.due_date as string) : '-'}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </>
  )
}
