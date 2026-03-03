import { createAdminClient } from '@/lib/supabase/admin'

export async function getClubsList() {
  const supabase = createAdminClient()

  const { data: clubs } = await supabase
    .from('clubs')
    .select('id, name, avatar_url, invite_code, address_city, address_state, created_at')
    .order('created_at', { ascending: false })

  if (!clubs) return []

  // Get counts per club
  const clubIds = clubs.map((c) => c.id)

  const [membersRes, sportsRes, courtsRes, challengesRes] = await Promise.all([
    supabase
      .from('club_members')
      .select('club_id')
      .in('club_id', clubIds)
      .eq('status', 'active'),
    supabase.from('club_sports').select('club_id').in('club_id', clubIds).eq('is_active', true),
    supabase.from('courts').select('club_id').in('club_id', clubIds).eq('is_active', true),
    supabase
      .from('challenges')
      .select('club_id')
      .in('club_id', clubIds)
      .eq('status', 'completed'),
  ])

  const countBy = (rows: { club_id: string }[] | null) => {
    const map: Record<string, number> = {}
    rows?.forEach((r) => {
      map[r.club_id] = (map[r.club_id] ?? 0) + 1
    })
    return map
  }

  const memberCounts = countBy(membersRes.data)
  const sportCounts = countBy(sportsRes.data)
  const courtCounts = countBy(courtsRes.data)
  const challengeCounts = countBy(challengesRes.data)

  return clubs.map((club) => ({
    ...club,
    members: memberCounts[club.id] ?? 0,
    sports: sportCounts[club.id] ?? 0,
    courts: courtCounts[club.id] ?? 0,
    challenges: challengeCounts[club.id] ?? 0,
  }))
}

export async function getClubDetail(clubId: string) {
  const supabase = createAdminClient()

  const [clubRes, membersRes, sportsRes, courtsRes, challengesRes] = await Promise.all([
    supabase
      .from('clubs')
      .select('*, creator:players!clubs_created_by_fkey(full_name)')
      .eq('id', clubId)
      .single(),
    supabase
      .from('club_members')
      .select(
        `id, role, ranking_position, status, joined_at, challenges_this_month,
         player:players(id, full_name, email, avatar_url, status, fee_status),
         sport:sports(name)`
      )
      .eq('club_id', clubId)
      .order('ranking_position'),
    supabase
      .from('club_sports')
      .select('id, is_active, sport:sports(name, icon)')
      .eq('club_id', clubId),
    supabase.from('courts').select('id, name, surface_type, is_active').eq('club_id', clubId),
    supabase
      .from('challenges')
      .select('id, status, created_at, completed_at')
      .eq('club_id', clubId)
      .order('created_at', { ascending: false })
      .limit(200),
  ])

  // Monthly challenge trend
  const challengesByMonth: Record<string, { created: number; completed: number }> = {}
  challengesRes.data?.forEach((c) => {
    const month = c.created_at.substring(0, 7)
    if (!challengesByMonth[month]) challengesByMonth[month] = { created: 0, completed: 0 }
    challengesByMonth[month].created++
    if (c.status === 'completed') challengesByMonth[month].completed++
  })

  const monthlyTrend = Object.entries(challengesByMonth)
    .sort(([a], [b]) => a.localeCompare(b))
    .slice(-12)
    .map(([month, vals]) => ({ month: month.substring(2), ...vals }))

  return {
    club: clubRes.data,
    members: membersRes.data ?? [],
    sports: sportsRes.data ?? [],
    courts: courtsRes.data ?? [],
    totalChallenges: challengesRes.data?.length ?? 0,
    completedChallenges: challengesRes.data?.filter((c) => c.status === 'completed').length ?? 0,
    monthlyTrend,
  }
}
