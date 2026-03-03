'use client'

import { ChartCard } from '@/components/chart-card'
import {
  BarChart,
  Bar,
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
} from 'recharts'

interface Props {
  byHour: { hora: string; reservas: number }[]
  byDay: { dia: string; reservas: number }[]
  dailyTrend: { date: string; reservas: number }[]
  byCourt: { quadra: string; reservas: number }[]
}

export function CourtCharts({ byHour, byDay, dailyTrend, byCourt }: Props) {
  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <ChartCard title="Reservas por Horario" subtitle="Ultimos 30 dias">
        <BarChart data={byHour}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey="hora" tick={{ fontSize: 11 }} />
          <YAxis tick={{ fontSize: 11 }} allowDecimals={false} />
          <Tooltip />
          <Bar dataKey="reservas" fill="#3b82f6" radius={[4, 4, 0, 0]} />
        </BarChart>
      </ChartCard>

      <ChartCard title="Reservas por Dia da Semana">
        <BarChart data={byDay}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey="dia" tick={{ fontSize: 11 }} />
          <YAxis tick={{ fontSize: 11 }} allowDecimals={false} />
          <Tooltip />
          <Bar dataKey="reservas" fill="#10b981" radius={[4, 4, 0, 0]} />
        </BarChart>
      </ChartCard>

      <ChartCard title="Trend Diario" subtitle="Reservas nos ultimos 30 dias">
        <LineChart data={dailyTrend}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey="date" tick={{ fontSize: 11 }} />
          <YAxis tick={{ fontSize: 11 }} allowDecimals={false} />
          <Tooltip />
          <Line type="monotone" dataKey="reservas" stroke="#3b82f6" strokeWidth={2} dot={false} />
        </LineChart>
      </ChartCard>

      <ChartCard title="Reservas por Quadra" subtitle="Top 10">
        <BarChart data={byCourt} layout="vertical">
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis type="number" tick={{ fontSize: 11 }} allowDecimals={false} />
          <YAxis dataKey="quadra" type="category" tick={{ fontSize: 9 }} width={100} />
          <Tooltip />
          <Bar dataKey="reservas" fill="#6366f1" radius={[0, 4, 4, 0]} />
        </BarChart>
      </ChartCard>
    </div>
  )
}
