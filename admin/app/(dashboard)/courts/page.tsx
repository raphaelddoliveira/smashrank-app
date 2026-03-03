import { Header } from '@/components/header'
import { StatCard } from '@/components/stat-card'
import { getCourtMetrics } from '@/lib/queries/courts'
import { SquareIcon, CalendarDays } from 'lucide-react'
import { CourtCharts } from './court-charts'

export const dynamic = 'force-dynamic'

export default async function CourtsPage() {
  const metrics = await getCourtMetrics()

  return (
    <>
      <Header title="Quadras" subtitle="Utilizacao e reservas" />

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-6">
        <StatCard label="Quadras Ativas" value={metrics.totalCourts} icon={SquareIcon} />
        <StatCard label="Reservas (30 dias)" value={metrics.totalReservations} icon={CalendarDays} />
      </div>

      <CourtCharts
        byHour={metrics.byHourChart}
        byDay={metrics.byDayChart}
        dailyTrend={metrics.dailyTrend}
        byCourt={metrics.byCourtChart}
      />
    </>
  )
}
