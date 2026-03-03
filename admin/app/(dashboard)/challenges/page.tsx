import { Header } from '@/components/header'
import { StatCard } from '@/components/stat-card'
import { getChallengeMetrics, getRecentChallengesList } from '@/lib/queries/challenges'
import { challengeStatusLabels, challengeStatusColors } from '@/lib/utils/constants'
import { formatDateTime } from '@/lib/utils/format'
import { StatusBadge } from '@/components/status-badge'
import { Swords, CheckCircle, AlertTriangle, Clock, TrendingUp } from 'lucide-react'
import { ChallengeCharts } from './challenge-charts'

export const dynamic = 'force-dynamic'

export default async function ChallengesPage() {
  const [metrics, recent] = await Promise.all([
    getChallengeMetrics(),
    getRecentChallengesList(),
  ])

  const { byStatus, total } = metrics
  const completed = byStatus['completed'] ?? 0
  const wos = (byStatus['wo_challenger'] ?? 0) + (byStatus['wo_challenged'] ?? 0)
  const pending =
    (byStatus['pending'] ?? 0) +
    (byStatus['dates_proposed'] ?? 0) +
    (byStatus['scheduled'] ?? 0) +
    (byStatus['pending_result'] ?? 0)
  const cancelled = (byStatus['cancelled'] ?? 0) + (byStatus['expired'] ?? 0)
  const completionRate =
    total - cancelled > 0 ? Math.round((completed / (total - cancelled)) * 100) : 0

  return (
    <>
      <Header title="Desafios" subtitle="Metricas e atividade de desafios" />

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-4 mb-6">
        <StatCard label="Total" value={total} icon={Swords} />
        <StatCard label="Concluidos" value={completed} icon={CheckCircle} />
        <StatCard label="WOs" value={wos} icon={AlertTriangle} />
        <StatCard label="Pendentes" value={pending} icon={Clock} />
        <StatCard label="Taxa Conclusao" value={`${completionRate}%`} icon={TrendingUp} />
      </div>

      <ChallengeCharts
        byMonth={metrics.byMonth}
        byClub={metrics.byClub}
        byStatus={byStatus}
      />

      {/* Recent challenges list */}
      <div className="bg-white rounded-xl border p-6 mt-6">
        <h3 className="text-base font-semibold text-gray-900 mb-4">
          Ultimos Desafios
        </h3>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b bg-gray-50">
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Desafiante</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Desafiado</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Clube</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Esporte</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Data</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {recent.slice(0, 50).map((c: Record<string, unknown>) => {
                const clubs = c.clubs as { name: string } | null
                const sport = c.sport as { name: string } | null
                const challenger = c.challenger as { full_name: string } | null
                const challenged = c.challenged as { full_name: string } | null
                return (
                  <tr key={c.id as string} className="hover:bg-gray-50">
                    <td className="px-4 py-3 text-gray-700">{challenger?.full_name ?? '-'}</td>
                    <td className="px-4 py-3 text-gray-700">{challenged?.full_name ?? '-'}</td>
                    <td className="px-4 py-3 text-gray-600">{clubs?.name ?? '-'}</td>
                    <td className="px-4 py-3 text-gray-600">{sport?.name ?? '-'}</td>
                    <td className="px-4 py-3">
                      <StatusBadge
                        label={challengeStatusLabels[c.status as string] ?? (c.status as string)}
                        colorClass={challengeStatusColors[c.status as string] ?? 'bg-gray-100 text-gray-800'}
                      />
                    </td>
                    <td className="px-4 py-3 text-gray-500 text-xs">{formatDateTime(c.created_at as string)}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </div>
    </>
  )
}
