import { Header } from '@/components/header'
import { StatCard } from '@/components/stat-card'
import { Building2, Users, Swords, CalendarDays, TrendingUp, UserCheck } from 'lucide-react'
import {
  getOverviewStats,
  getRecentChallenges,
  getChallengesTrend,
  getUserGrowth,
} from '@/lib/queries/overview'
import { OverviewCharts } from './overview-charts'
import { formatDateTime } from '@/lib/utils/format'
import { challengeStatusLabels, challengeStatusColors } from '@/lib/utils/constants'
import { StatusBadge } from '@/components/status-badge'

export const dynamic = 'force-dynamic'

export default async function DashboardPage() {
  const [stats, recent, trend, growth] = await Promise.all([
    getOverviewStats(),
    getRecentChallenges(),
    getChallengesTrend(),
    getUserGrowth(),
  ])

  return (
    <>
      <Header title="Visao Geral" subtitle="Resumo da plataforma SmashRank" />

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4 mb-6">
        <StatCard label="Clubes" value={stats.totalClubs} icon={Building2} />
        <StatCard label="Jogadores" value={stats.totalPlayers} icon={Users} />
        <StatCard label="Ativos" value={stats.activePlayers} icon={UserCheck} />
        <StatCard label="Desafios (mes)" value={stats.challengesThisMonth} icon={Swords} />
        <StatCard label="Reservas (mes)" value={stats.reservationsThisMonth} icon={CalendarDays} />
        <StatCard
          label="Taxa Conclusao"
          value={`${stats.completionRate}%`}
          icon={TrendingUp}
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        <OverviewCharts trend={trend} growth={growth} />
      </div>

      <div className="bg-white rounded-xl border p-6">
        <h3 className="text-base font-semibold text-gray-900 mb-4">Atividade Recente</h3>
        <div className="space-y-3">
          {recent.map((c: Record<string, unknown>) => {
            const clubs = c.clubs as { name: string } | null
            const challenger = c.challenger as { full_name: string } | null
            const challenged = c.challenged as { full_name: string } | null
            return (
              <div
                key={c.id as string}
                className="flex items-center justify-between py-2 border-b last:border-0"
              >
                <div className="flex-1">
                  <p className="text-sm text-gray-900">
                    <span className="font-medium">{challenger?.full_name}</span>
                    {' vs '}
                    <span className="font-medium">{challenged?.full_name}</span>
                  </p>
                  <p className="text-xs text-gray-500">
                    {clubs?.name} &middot;{' '}
                    {c.completed_at ? formatDateTime(c.completed_at as string) : '-'}
                  </p>
                </div>
                <StatusBadge
                  label={challengeStatusLabels[c.status as string] ?? (c.status as string)}
                  colorClass={challengeStatusColors[c.status as string] ?? 'bg-gray-100 text-gray-800'}
                />
              </div>
            )
          })}
          {recent.length === 0 && (
            <p className="text-sm text-gray-400 text-center py-4">Nenhuma atividade recente.</p>
          )}
        </div>
      </div>
    </>
  )
}
