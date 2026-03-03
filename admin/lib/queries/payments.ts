import { createAdminClient } from '@/lib/supabase/admin'

export async function getPaymentMetrics() {
  const supabase = createAdminClient()

  const { data: fees } = await supabase
    .from('monthly_fees')
    .select('id, player_id, reference_month, amount, status, due_date, paid_at')
    .order('reference_month', { ascending: false })

  if (!fees) return { byStatus: { paid: 0, pending: 0, overdue: 0 }, totalRevenue: 0, byMonth: [], overduePlayers: [] }

  const byStatus = { paid: 0, pending: 0, overdue: 0 }
  let totalRevenue = 0

  fees.forEach((f) => {
    if (f.status in byStatus) byStatus[f.status as keyof typeof byStatus]++
    if (f.status === 'paid') totalRevenue += parseFloat(String(f.amount))
  })

  // By month (revenue)
  const byMonthMap: Record<string, number> = {}
  fees.forEach((f) => {
    if (f.status === 'paid' && f.reference_month) {
      const month = String(f.reference_month).substring(0, 7)
      byMonthMap[month] = (byMonthMap[month] ?? 0) + parseFloat(String(f.amount))
    }
  })

  const byMonth = Object.entries(byMonthMap)
    .sort(([a], [b]) => a.localeCompare(b))
    .slice(-12)
    .map(([month, amount]) => ({ month: month.substring(2), receita: Math.round(amount) }))

  return {
    byStatus,
    totalRevenue,
    byMonth,
    total: fees.length,
  }
}

export async function getOverduePlayers() {
  const supabase = createAdminClient()

  const { data } = await supabase
    .from('monthly_fees')
    .select('id, reference_month, amount, due_date, player:players(id, full_name, email)')
    .eq('status', 'overdue')
    .order('due_date')

  return data ?? []
}
