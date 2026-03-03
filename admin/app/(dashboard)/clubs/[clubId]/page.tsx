import { Header } from '@/components/header'
import { StatCard } from '@/components/stat-card'
import { StatusBadge } from '@/components/status-badge'
import { getClubDetail } from '@/lib/queries/clubs'
import { formatDate } from '@/lib/utils/format'
import { playerStatusLabels, playerStatusColors, paymentStatusLabels, paymentStatusColors } from '@/lib/utils/constants'
import { Users, Swords, TrendingUp, SquareIcon } from 'lucide-react'
import { ClubDetailCharts } from './club-detail-charts'
import Link from 'next/link'

export const dynamic = 'force-dynamic'

export default async function ClubDetailPage({ params }: { params: Promise<{ clubId: string }> }) {
  const { clubId } = await params
  const { club, members, sports, courts, totalChallenges, completedChallenges, monthlyTrend } =
    await getClubDetail(clubId)

  if (!club) {
    return <p className="text-gray-500 p-8">Clube nao encontrado.</p>
  }

  const creator = club.creator as { full_name: string } | null
  const activeMembers = members.filter(
    (m: Record<string, unknown>) => m.status === 'active'
  ).length

  return (
    <>
      <div className="mb-2">
        <Link href="/clubs" className="text-sm text-blue-600 hover:underline">
          &larr; Voltar para clubes
        </Link>
      </div>

      <Header
        title={club.name}
        subtitle={`Criado por ${creator?.full_name ?? '-'} em ${formatDate(club.created_at)}`}
      />

      {(club.address_city || club.phone || club.email) && (
        <div className="bg-white rounded-xl border p-4 mb-6 text-sm text-gray-600 space-y-1">
          {club.address_city && (
            <p>
              {[club.address_street, club.address_number, club.address_neighborhood, club.address_city, club.address_state]
                .filter(Boolean)
                .join(', ')}
            </p>
          )}
          {club.phone && <p>Tel: {club.phone}</p>}
          {club.email && <p>Email: {club.email}</p>}
        </div>
      )}

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <StatCard label="Membros Ativos" value={activeMembers} icon={Users} />
        <StatCard label="Total Membros" value={members.length} icon={Users} />
        <StatCard label="Desafios" value={totalChallenges} icon={Swords} />
        <StatCard
          label="Taxa Conclusao"
          value={totalChallenges > 0 ? `${Math.round((completedChallenges / totalChallenges) * 100)}%` : '-'}
          icon={TrendingUp}
        />
      </div>

      {/* Sports and Courts summary */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        <div className="bg-white rounded-xl border p-6">
          <h3 className="text-base font-semibold text-gray-900 mb-3">Esportes</h3>
          <div className="space-y-2">
            {sports.map((s: Record<string, unknown>) => {
              const sport = s.sport as { name: string; icon: string } | null
              return (
                <div key={s.id as string} className="flex items-center justify-between py-1">
                  <span className="text-sm text-gray-700">{sport?.name ?? '-'}</span>
                  <StatusBadge
                    label={s.is_active ? 'Ativo' : 'Inativo'}
                    colorClass={s.is_active ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'}
                  />
                </div>
              )
            })}
            {sports.length === 0 && <p className="text-sm text-gray-400">Nenhum esporte configurado.</p>}
          </div>
        </div>

        <div className="bg-white rounded-xl border p-6">
          <h3 className="text-base font-semibold text-gray-900 mb-3">Quadras</h3>
          <div className="space-y-2">
            {courts.map((c: Record<string, unknown>) => (
              <div key={c.id as string} className="flex items-center justify-between py-1">
                <div>
                  <span className="text-sm text-gray-700">{c.name as string}</span>
                  {c.surface_type ? (
                    <span className="text-xs text-gray-400 ml-2">({c.surface_type as string})</span>
                  ) : null}
                </div>
                <StatusBadge
                  label={c.is_active ? 'Ativa' : 'Inativa'}
                  colorClass={c.is_active ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'}
                />
              </div>
            ))}
            {courts.length === 0 && <p className="text-sm text-gray-400">Nenhuma quadra cadastrada.</p>}
          </div>
        </div>
      </div>

      {monthlyTrend.length > 0 && <ClubDetailCharts monthlyTrend={monthlyTrend} />}

      {/* Members table */}
      <div className="bg-white rounded-xl border p-6 mt-6">
        <h3 className="text-base font-semibold text-gray-900 mb-4">
          Membros ({members.length})
        </h3>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b bg-gray-50">
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">#</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Nome</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Esporte</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Role</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Pgto</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Desafios/Mes</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {members.map((m: Record<string, unknown>) => {
                const player = m.player as { id: string; full_name: string; status: string; fee_status: string } | null
                const sport = m.sport as { name: string } | null
                return (
                  <tr key={m.id as string} className="hover:bg-gray-50">
                    <td className="px-4 py-3 text-gray-700">{m.ranking_position as number}</td>
                    <td className="px-4 py-3">
                      <Link
                        href={`/users/${player?.id}`}
                        className="text-blue-600 hover:underline font-medium"
                      >
                        {player?.full_name ?? '-'}
                      </Link>
                    </td>
                    <td className="px-4 py-3 text-gray-600">{sport?.name ?? '-'}</td>
                    <td className="px-4 py-3">
                      <StatusBadge
                        label={m.role === 'admin' ? 'Admin' : 'Membro'}
                        colorClass={m.role === 'admin' ? 'bg-purple-100 text-purple-800' : 'bg-gray-100 text-gray-600'}
                      />
                    </td>
                    <td className="px-4 py-3">
                      <StatusBadge
                        label={playerStatusLabels[player?.status ?? ''] ?? (player?.status ?? '-')}
                        colorClass={playerStatusColors[player?.status ?? ''] ?? 'bg-gray-100 text-gray-800'}
                      />
                    </td>
                    <td className="px-4 py-3">
                      <StatusBadge
                        label={paymentStatusLabels[player?.fee_status ?? ''] ?? (player?.fee_status ?? '-')}
                        colorClass={paymentStatusColors[player?.fee_status ?? ''] ?? 'bg-gray-100 text-gray-800'}
                      />
                    </td>
                    <td className="px-4 py-3 text-gray-700">{m.challenges_this_month as number ?? 0}</td>
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
