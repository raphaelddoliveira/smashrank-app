import { createAdminClient } from '@/lib/supabase/admin'

export async function getUsersList() {
  const supabase = createAdminClient()

  const { data: players } = await supabase
    .from('players')
    .select('id, full_name, email, nickname, avatar_url, role, status, fee_status, created_at')
    .order('created_at', { ascending: false })

  if (!players) return []

  // Get club membership counts
  const playerIds = players.map((p) => p.id)
  const { data: memberships } = await supabase
    .from('club_members')
    .select('player_id, club_id')
    .in('player_id', playerIds)
    .eq('status', 'active')

  const clubCounts: Record<string, number> = {}
  const seen: Record<string, Set<string>> = {}
  memberships?.forEach((m) => {
    if (!seen[m.player_id]) seen[m.player_id] = new Set()
    if (!seen[m.player_id].has(m.club_id)) {
      seen[m.player_id].add(m.club_id)
      clubCounts[m.player_id] = (clubCounts[m.player_id] ?? 0) + 1
    }
  })

  return players.map((p) => ({
    ...p,
    clubCount: clubCounts[p.id] ?? 0,
  }))
}

export async function getUserDetail(userId: string) {
  const supabase = createAdminClient()

  const [playerRes, membershipsRes, challengesRes, feesRes] = await Promise.all([
    supabase.from('players').select('*').eq('id', userId).single(),
    supabase
      .from('club_members')
      .select(
        `id, role, ranking_position, status, joined_at, challenges_this_month,
         club:clubs(id, name),
         sport:sports(name)`
      )
      .eq('player_id', userId)
      .order('ranking_position'),
    supabase
      .from('challenges')
      .select(
        `id, status, created_at, completed_at,
         clubs(name),
         challenger:players!challenges_challenger_id_fkey(full_name),
         challenged:players!challenges_challenged_id_fkey(full_name)`
      )
      .or(`challenger_id.eq.${userId},challenged_id.eq.${userId}`)
      .order('created_at', { ascending: false })
      .limit(50),
    supabase
      .from('monthly_fees')
      .select('*')
      .eq('player_id', userId)
      .order('reference_month', { ascending: false })
      .limit(12),
  ])

  return {
    player: playerRes.data,
    memberships: membershipsRes.data ?? [],
    challenges: challengesRes.data ?? [],
    fees: feesRes.data ?? [],
  }
}
