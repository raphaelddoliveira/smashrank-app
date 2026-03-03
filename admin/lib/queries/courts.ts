import { createAdminClient } from '@/lib/supabase/admin'

export async function getCourtMetrics() {
  const supabase = createAdminClient()
  const thirtyDaysAgo = new Date()
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)

  const [courtsRes, reservationsRes] = await Promise.all([
    supabase
      .from('courts')
      .select('id, name, club_id, is_active, clubs(name)')
      .eq('is_active', true),
    supabase
      .from('court_reservations')
      .select('id, court_id, reservation_date, start_time, status, club_id')
      .gte('reservation_date', thirtyDaysAgo.toISOString().split('T')[0])
      .eq('status', 'confirmed'),
  ])

  const reservations = reservationsRes.data ?? []
  const courts = courtsRes.data ?? []

  // By hour
  const byHour: Record<string, number> = {}
  reservations.forEach((r) => {
    const hour = r.start_time.substring(0, 2)
    byHour[hour] = (byHour[hour] ?? 0) + 1
  })

  const byHourChart = Object.entries(byHour)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([hour, count]) => ({ hora: `${hour}h`, reservas: count }))

  // By day of week
  const dayNames = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab']
  const byDayMap: Record<number, number> = {}
  reservations.forEach((r) => {
    const day = new Date(r.reservation_date + 'T12:00:00').getDay()
    byDayMap[day] = (byDayMap[day] ?? 0) + 1
  })

  const byDayChart = dayNames.map((name, i) => ({
    dia: name,
    reservas: byDayMap[i] ?? 0,
  }))

  // Daily trend (last 30 days)
  const byDate: Record<string, number> = {}
  reservations.forEach((r) => {
    byDate[r.reservation_date] = (byDate[r.reservation_date] ?? 0) + 1
  })

  const dailyTrend = Object.entries(byDate)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([date, count]) => ({ date: date.substring(5), reservas: count }))

  // By court
  const byCourtMap: Record<string, number> = {}
  reservations.forEach((r) => {
    byCourtMap[r.court_id] = (byCourtMap[r.court_id] ?? 0) + 1
  })

  const courtNameMap: Record<string, string> = {}
  courts.forEach((c) => {
    const club = c.clubs as unknown as { name: string } | null
    courtNameMap[c.id] = `${c.name} (${club?.name ?? ''})`
  })

  const byCourtChart = Object.entries(byCourtMap)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 10)
    .map(([id, count]) => ({
      quadra: courtNameMap[id] ?? id.substring(0, 8),
      reservas: count,
    }))

  return {
    totalCourts: courts.length,
    totalReservations: reservations.length,
    byHourChart,
    byDayChart,
    dailyTrend,
    byCourtChart,
  }
}
