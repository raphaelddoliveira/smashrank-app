import { createAdminClient } from '@/lib/supabase/admin'

export async function getOverviewStats() {
  const supabase = createAdminClient()
  const now = new Date()
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString()

  const [clubs, players, activePlayers, challengesMonth, reservationsMonth, completedMonth] =
    await Promise.all([
      supabase.from('clubs').select('*', { count: 'exact', head: true }),
      supabase.from('players').select('*', { count: 'exact', head: true }),
      supabase
        .from('players')
        .select('*', { count: 'exact', head: true })
        .eq('status', 'active'),
      supabase
        .from('challenges')
        .select('*', { count: 'exact', head: true })
        .gte('created_at', monthStart),
      supabase
        .from('court_reservations')
        .select('*', { count: 'exact', head: true })
        .gte('reservation_date', monthStart),
      supabase
        .from('challenges')
        .select('*', { count: 'exact', head: true })
        .eq('status', 'completed')
        .gte('completed_at', monthStart),
    ])

  const totalChallenges = challengesMonth.count ?? 0
  const totalCompleted = completedMonth.count ?? 0
  const completionRate =
    totalChallenges > 0 ? Math.round((totalCompleted / totalChallenges) * 100) : 0

  return {
    totalClubs: clubs.count ?? 0,
    totalPlayers: players.count ?? 0,
    activePlayers: activePlayers.count ?? 0,
    challengesThisMonth: totalChallenges,
    reservationsThisMonth: reservationsMonth.count ?? 0,
    completionRate,
  }
}

export async function getRecentChallenges() {
  const supabase = createAdminClient()

  const { data } = await supabase
    .from('challenges')
    .select(
      `id, status, completed_at, created_at,
       clubs(name),
       challenger:players!challenges_challenger_id_fkey(full_name),
       challenged:players!challenges_challenged_id_fkey(full_name)`
    )
    .in('status', ['completed', 'wo_challenger', 'wo_challenged'])
    .order('completed_at', { ascending: false })
    .limit(10)

  return data ?? []
}

export async function getChallengesTrend() {
  const supabase = createAdminClient()
  const thirtyDaysAgo = new Date()
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)

  const { data } = await supabase
    .from('challenges')
    .select('created_at, status')
    .gte('created_at', thirtyDaysAgo.toISOString())

  if (!data) return []

  const byDay: Record<string, { total: number; completed: number }> = {}
  data.forEach((c) => {
    const day = c.created_at.substring(0, 10)
    if (!byDay[day]) byDay[day] = { total: 0, completed: 0 }
    byDay[day].total++
    if (c.status === 'completed') byDay[day].completed++
  })

  return Object.entries(byDay)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([date, vals]) => ({
      date: date.substring(5), // MM-DD
      total: vals.total,
      completed: vals.completed,
    }))
}

export async function getUserGrowth() {
  const supabase = createAdminClient()
  const sixMonthsAgo = new Date()
  sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6)

  const { data } = await supabase
    .from('players')
    .select('created_at')
    .gte('created_at', sixMonthsAgo.toISOString())
    .order('created_at')

  if (!data) return []

  const byWeek: Record<string, number> = {}
  data.forEach((p) => {
    const d = new Date(p.created_at)
    const weekStart = new Date(d)
    weekStart.setDate(d.getDate() - d.getDay())
    const key = weekStart.toISOString().substring(0, 10)
    byWeek[key] = (byWeek[key] ?? 0) + 1
  })

  return Object.entries(byWeek)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([week, count]) => ({
      week: week.substring(5),
      novos: count,
    }))
}
