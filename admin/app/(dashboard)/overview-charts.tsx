'use client'

import { ChartCard } from '@/components/chart-card'
import {
  LineChart,
  Line,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
} from 'recharts'

interface OverviewChartsProps {
  trend: { date: string; total: number; completed: number }[]
  growth: { week: string; novos: number }[]
}

export function OverviewCharts({ trend, growth }: OverviewChartsProps) {
  return (
    <>
      <ChartCard title="Desafios (ultimos 30 dias)" subtitle="Criados vs Concluidos">
        <LineChart data={trend}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey="date" tick={{ fontSize: 11 }} />
          <YAxis tick={{ fontSize: 11 }} allowDecimals={false} />
          <Tooltip />
          <Line
            type="monotone"
            dataKey="total"
            stroke="#3b82f6"
            strokeWidth={2}
            name="Criados"
            dot={false}
          />
          <Line
            type="monotone"
            dataKey="completed"
            stroke="#10b981"
            strokeWidth={2}
            name="Concluidos"
            dot={false}
          />
        </LineChart>
      </ChartCard>

      <ChartCard title="Novos Usuarios (por semana)" subtitle="Ultimos 6 meses">
        <BarChart data={growth}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey="week" tick={{ fontSize: 11 }} />
          <YAxis tick={{ fontSize: 11 }} allowDecimals={false} />
          <Tooltip />
          <Bar dataKey="novos" fill="#3b82f6" radius={[4, 4, 0, 0]} name="Novos" />
        </BarChart>
      </ChartCard>
    </>
  )
}
