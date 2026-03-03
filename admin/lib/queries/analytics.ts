import { createAdminClient } from '@/lib/supabase/admin'

export async function getUserGrowthCumulative() {
  const supabase = createAdminClient()

  const { data: players } = await supabase
    .from('players')
    .select('created_at')
    .order('created_at')

  if (!players) return []

  const byMonth: Record<string, number> = {}
  let cumulative = 0
  players.forEach((p) => {
    const month = p.created_at.substring(0, 7)
    cumulative++
    byMonth[month] = cumulative
  })

  return Object.entries(byMonth).map(([month, count]) => ({
    month: month.substring(2),
    usuarios: count,
  }))
}

export async function getChallengesByClubMonthly() {
  const supabase = createAdminClient()
  const sixMonthsAgo = new Date()
  sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6)

  const [challengesRes, clubsRes] = await Promise.all([
    supabase
      .from('challenges')
      .select('club_id, created_at')
      .gte('created_at', sixMonthsAgo.toISOString()),
    supabase.from('clubs').select('id, name'),
  ])

  if (!challengesRes.data || !clubsRes.data) return { months: [], clubs: [] }

  const clubNameMap: Record<string, string> = {}
  clubsRes.data.forEach((c) => {
    clubNameMap[c.id] = c.name
  })

  // Group by month, then by club
  const monthClub: Record<string, Record<string, number>> = {}
  const allClubs = new Set<string>()

  challengesRes.data.forEach((c) => {
    const month = c.created_at.substring(0, 7)
    if (!monthClub[month]) monthClub[month] = {}
    const clubName = clubNameMap[c.club_id] ?? 'Desconhecido'
    allClubs.add(clubName)
    monthClub[month][clubName] = (monthClub[month][clubName] ?? 0) + 1
  })

  const months = Object.entries(monthClub)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([month, clubs]) => ({
      month: month.substring(2),
      ...clubs,
    }))

  return {
    months,
    clubs: Array.from(allClubs),
  }
}

export async function getClubComparison() {
  const supabase = createAdminClient()

  const [clubsRes, membersRes, challengesRes, reservationsRes] = await Promise.all([
    supabase.from('clubs').select('id, name'),
    supabase.from('club_members').select('club_id').eq('status', 'active'),
    supabase.from('challenges').select('club_id').eq('status', 'completed'),
    supabase.from('court_reservations').select('club_id').eq('status', 'confirmed'),
  ])

  if (!clubsRes.data) return []

  const countBy = (rows: { club_id: string }[] | null) => {
    const map: Record<string, number> = {}
    rows?.forEach((r) => {
      map[r.club_id] = (map[r.club_id] ?? 0) + 1
    })
    return map
  }

  const memberCounts = countBy(membersRes.data)
  const challengeCounts = countBy(challengesRes.data)
  const reservationCounts = countBy(reservationsRes.data)

  return clubsRes.data.map((club) => ({
    name: club.name,
    membros: memberCounts[club.id] ?? 0,
    desafios: challengeCounts[club.id] ?? 0,
    reservas: reservationCounts[club.id] ?? 0,
  }))
}
