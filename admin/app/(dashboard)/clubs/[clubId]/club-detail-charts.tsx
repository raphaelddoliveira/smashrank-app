'use client'

import { ChartCard } from '@/components/chart-card'
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip } from 'recharts'

interface Props {
  monthlyTrend: { month: string; created: number; completed: number }[]
}

export function ClubDetailCharts({ monthlyTrend }: Props) {
  return (
    <ChartCard title="Desafios por Mes" subtitle="Criados vs Concluidos">
      <BarChart data={monthlyTrend}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="month" tick={{ fontSize: 11 }} />
        <YAxis tick={{ fontSize: 11 }} allowDecimals={false} />
        <Tooltip />
        <Bar dataKey="created" fill="#3b82f6" radius={[4, 4, 0, 0]} name="Criados" />
        <Bar dataKey="completed" fill="#10b981" radius={[4, 4, 0, 0]} name="Concluidos" />
      </BarChart>
    </ChartCard>
  )
}
