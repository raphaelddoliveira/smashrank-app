'use client'

import { ChartCard } from '@/components/chart-card'
import {
  AreaChart,
  Area,
  BarChart,
  Bar,
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
} from 'recharts'

const COLORS = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#6366f1', '#8b5cf6', '#ec4899', '#14b8a6']

interface Props {
  userGrowth: { month: string; usuarios: number }[]
  challengesByClub: {
    months: Record<string, unknown>[]
    clubs: string[]
  }
  clubComparison: { name: string; membros: number; desafios: number; reservas: number }[]
}

export function AnalyticsCharts({ userGrowth, challengesByClub, clubComparison }: Props) {
  return (
    <div className="grid grid-cols-1 gap-6">
      <ChartCard title="Crescimento de Usuarios" subtitle="Acumulado por mes" height={350}>
        <AreaChart data={userGrowth}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey="month" tick={{ fontSize: 11 }} />
          <YAxis tick={{ fontSize: 11 }} />
          <Tooltip />
          <Area
            type="monotone"
            dataKey="usuarios"
            stroke="#3b82f6"
            fill="#3b82f6"
            fillOpacity={0.15}
            strokeWidth={2}
            name="Usuarios"
          />
        </AreaChart>
      </ChartCard>

      {challengesByClub.months.length > 0 && (
        <ChartCard title="Desafios por Clube (mensal)" subtitle="Ultimos 6 meses" height={350}>
          <LineChart data={challengesByClub.months}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey="month" tick={{ fontSize: 11 }} />
            <YAxis tick={{ fontSize: 11 }} allowDecimals={false} />
            <Tooltip />
            <Legend />
            {challengesByClub.clubs.map((club, i) => (
              <Line
                key={club}
                type="monotone"
                dataKey={club}
                stroke={COLORS[i % COLORS.length]}
                strokeWidth={2}
                dot={false}
              />
            ))}
          </LineChart>
        </ChartCard>
      )}

      {clubComparison.length > 0 && (
        <ChartCard title="Comparacao entre Clubes" subtitle="Membros, desafios e reservas" height={350}>
          <BarChart data={clubComparison}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey="name" tick={{ fontSize: 10 }} />
            <YAxis tick={{ fontSize: 11 }} allowDecimals={false} />
            <Tooltip />
            <Legend />
            <Bar dataKey="membros" fill="#3b82f6" radius={[4, 4, 0, 0]} name="Membros" />
            <Bar dataKey="desafios" fill="#10b981" radius={[4, 4, 0, 0]} name="Desafios" />
            <Bar dataKey="reservas" fill="#f59e0b" radius={[4, 4, 0, 0]} name="Reservas" />
          </BarChart>
        </ChartCard>
      )}
    </div>
  )
}
