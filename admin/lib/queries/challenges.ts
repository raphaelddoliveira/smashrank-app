import { createAdminClient } from '@/lib/supabase/admin'

export async function getChallengeMetrics() {
  const supabase = createAdminClient()

  const { data: challenges } = await supabase
    .from('challenges')
    .select('id, status, created_at, completed_at, club_id')
    .order('created_at', { ascending: false })

  if (!challenges) return { byStatus: {} as Record<string, number>, byMonth: [] as { month: string; created: number; completed: number; wo: number }[], byClub: [] as { name: string; desafios: number }[], total: 0 }

  // By status
  const byStatus: Record<string, number> = {}
  challenges.forEach((c) => {
    byStatus[c.status] = (byStatus[c.status] ?? 0) + 1
  })

  // By month (last 12 months)
  const byMonthMap: Record<string, { created: number; completed: number; wo: number }> = {}
  challenges.forEach((c) => {
    const month = c.created_at.substring(0, 7)
    if (!byMonthMap[month]) byMonthMap[month] = { created: 0, completed: 0, wo: 0 }
    byMonthMap[month].created++
    if (c.status === 'completed') byMonthMap[month].completed++
    if (c.status === 'wo_challenger' || c.status === 'wo_challenged') byMonthMap[month].wo++
  })

  const byMonth = Object.entries(byMonthMap)
    .sort(([a], [b]) => a.localeCompare(b))
    .slice(-12)
    .map(([month, vals]) => ({ month: month.substring(2), ...vals }))

  // By club (top 10)
  const byClubMap: Record<string, number> = {}
  challenges.forEach((c) => {
    if (c.club_id) byClubMap[c.club_id] = (byClubMap[c.club_id] ?? 0) + 1
  })

  const topClubIds = Object.entries(byClubMap)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 10)
    .map(([id]) => id)

  // Fetch club names for top clubs
  const { data: clubNames } = await supabase
    .from('clubs')
    .select('id, name')
    .in('id', topClubIds)

  const clubNameMap: Record<string, string> = {}
  clubNames?.forEach((c) => {
    clubNameMap[c.id] = c.name
  })

  const byClub = topClubIds.map((id) => ({
    name: clubNameMap[id] ?? id.substring(0, 8),
    desafios: byClubMap[id],
  }))

  return {
    byStatus,
    byMonth,
    byClub,
    total: challenges.length,
  }
}

export async function getRecentChallengesList() {
  const supabase = createAdminClient()

  const { data } = await supabase
    .from('challenges')
    .select(
      `id, status, created_at, completed_at,
       clubs(name),
       sport:sports(name),
       challenger:players!challenges_challenger_id_fkey(full_name),
       challenged:players!challenges_challenged_id_fkey(full_name)`
    )
    .order('created_at', { ascending: false })
    .limit(100)

  return data ?? []
}
