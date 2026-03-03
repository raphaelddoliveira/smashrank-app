import { Header } from '@/components/header'
import { StatusBadge } from '@/components/status-badge'
import { getUserDetail } from '@/lib/queries/users'
import { formatDate, formatDateTime, formatCurrency } from '@/lib/utils/format'
import {
  playerStatusLabels,
  playerStatusColors,
  paymentStatusLabels,
  paymentStatusColors,
  challengeStatusLabels,
  challengeStatusColors,
} from '@/lib/utils/constants'
import Link from 'next/link'

export const dynamic = 'force-dynamic'

export default async function UserDetailPage({ params }: { params: Promise<{ userId: string }> }) {
  const { userId } = await params
  const { player, memberships, challenges, fees } = await getUserDetail(userId)

  if (!player) {
    return <p className="text-gray-500 p-8">Usuario nao encontrado.</p>
  }

  return (
    <>
      <div className="mb-2">
        <Link href="/users" className="text-sm text-blue-600 hover:underline">
          &larr; Voltar para usuarios
        </Link>
      </div>

      <Header title={player.full_name} subtitle={player.email} />

      {/* Profile info */}
      <div className="bg-white rounded-xl border p-6 mb-6">
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 text-sm">
          <div>
            <p className="text-gray-500">Status</p>
            <StatusBadge
              label={playerStatusLabels[player.status] ?? player.status}
              colorClass={playerStatusColors[player.status] ?? 'bg-gray-100 text-gray-800'}
            />
          </div>
          <div>
            <p className="text-gray-500">Pagamento</p>
            <StatusBadge
              label={paymentStatusLabels[player.fee_status] ?? player.fee_status}
              colorClass={paymentStatusColors[player.fee_status] ?? 'bg-gray-100 text-gray-800'}
            />
          </div>
          <div>
            <p className="text-gray-500">Role</p>
            <p className="text-gray-900 font-medium mt-1">{player.role}</p>
          </div>
          <div>
            <p className="text-gray-500">Cadastro</p>
            <p className="text-gray-900 mt-1">{formatDate(player.created_at)}</p>
          </div>
          {player.phone && (
            <div>
              <p className="text-gray-500">Telefone</p>
              <p className="text-gray-900 mt-1">{player.phone}</p>
            </div>
          )}
          {player.nickname && (
            <div>
              <p className="text-gray-500">Apelido</p>
              <p className="text-gray-900 mt-1">{player.nickname}</p>
            </div>
          )}
        </div>
      </div>

      {/* Memberships */}
      <div className="bg-white rounded-xl border p-6 mb-6">
        <h3 className="text-base font-semibold text-gray-900 mb-4">
          Clubes ({memberships.length})
        </h3>
        {memberships.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b bg-gray-50">
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Clube</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Esporte</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Ranking</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Role</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Entrada</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {memberships.map((m: Record<string, unknown>) => {
                  const club = m.club as { id: string; name: string } | null
                  const sport = m.sport as { name: string } | null
                  return (
                    <tr key={m.id as string} className="hover:bg-gray-50">
                      <td className="px-4 py-3">
                        <Link href={`/clubs/${club?.id}`} className="text-blue-600 hover:underline">
                          {club?.name ?? '-'}
                        </Link>
                      </td>
                      <td className="px-4 py-3 text-gray-600">{sport?.name ?? '-'}</td>
                      <td className="px-4 py-3 text-gray-700 font-medium">#{m.ranking_position as number}</td>
                      <td className="px-4 py-3">
                        <StatusBadge
                          label={m.role === 'admin' ? 'Admin' : 'Membro'}
                          colorClass={m.role === 'admin' ? 'bg-purple-100 text-purple-800' : 'bg-gray-100 text-gray-600'}
                        />
                      </td>
                      <td className="px-4 py-3 text-gray-600">{m.joined_at ? formatDate(m.joined_at as string) : '-'}</td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="text-sm text-gray-400">Nao participa de nenhum clube.</p>
        )}
      </div>

      {/* Recent challenges */}
      <div className="bg-white rounded-xl border p-6 mb-6">
        <h3 className="text-base font-semibold text-gray-900 mb-4">
          Desafios Recentes ({challenges.length})
        </h3>
        {challenges.length > 0 ? (
          <div className="space-y-3">
            {challenges.map((c: Record<string, unknown>) => {
              const clubs = c.clubs as { name: string } | null
              const challenger = c.challenger as { full_name: string } | null
              const challenged = c.challenged as { full_name: string } | null
              return (
                <div key={c.id as string} className="flex items-center justify-between py-2 border-b last:border-0">
                  <div>
                    <p className="text-sm text-gray-900">
                      {challenger?.full_name} vs {challenged?.full_name}
                    </p>
                    <p className="text-xs text-gray-500">
                      {clubs?.name} &middot; {formatDateTime(c.created_at as string)}
                    </p>
                  </div>
                  <StatusBadge
                    label={challengeStatusLabels[c.status as string] ?? (c.status as string)}
                    colorClass={challengeStatusColors[c.status as string] ?? 'bg-gray-100 text-gray-800'}
                  />
                </div>
              )
            })}
          </div>
        ) : (
          <p className="text-sm text-gray-400">Nenhum desafio encontrado.</p>
        )}
      </div>

      {/* Fees */}
      {fees.length > 0 && (
        <div className="bg-white rounded-xl border p-6">
          <h3 className="text-base font-semibold text-gray-900 mb-4">Mensalidades</h3>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b bg-gray-50">
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Referencia</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Valor</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Vencimento</th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Pago em</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {fees.map((f: Record<string, unknown>) => (
                  <tr key={f.id as string} className="hover:bg-gray-50">
                    <td className="px-4 py-3 text-gray-700">{formatDate(f.reference_month as string)}</td>
                    <td className="px-4 py-3 text-gray-700">{formatCurrency(Number(f.amount))}</td>
                    <td className="px-4 py-3">
                      <StatusBadge
                        label={paymentStatusLabels[f.status as string] ?? (f.status as string)}
                        colorClass={paymentStatusColors[f.status as string] ?? 'bg-gray-100 text-gray-800'}
                      />
                    </td>
                    <td className="px-4 py-3 text-gray-600">{f.due_date ? formatDate(f.due_date as string) : '-'}</td>
                    <td className="px-4 py-3 text-gray-600">{f.paid_at ? formatDate(f.paid_at as string) : '-'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </>
  )
}
