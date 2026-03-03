'use client'

import { ChartCard } from '@/components/chart-card'
import {
  LineChart,
  Line,
  BarChart,
  Bar,
  PieChart,
  Pie,
  Cell,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  type PieLabelRenderProps,
} from 'recharts'
import { challengeStatusLabels } from '@/lib/utils/constants'

const COLORS = ['#10b981', '#3b82f6', '#f59e0b', '#ef4444', '#6366f1', '#8b5cf6', '#ec4899', '#14b8a6', '#f97316']

interface Props {
  byMonth: { month: string; created: number; completed: number; wo: number }[]
  byClub: { name: string; desafios: number }[]
  byStatus: Record<string, number>
}

export function ChallengeCharts({ byMonth, byClub, byStatus }: Props) {
  const pieData = Object.entries(byStatus).map(([status, count]) => ({
    name: challengeStatusLabels[status] ?? status,
    value: count,
  }))

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-6">
      <ChartCard title="Desafios por Mes" subtitle="Ultimos 12 meses">
        <LineChart data={byMonth}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey="month" tick={{ fontSize: 11 }} />
          <YAxis tick={{ fontSize: 11 }} allowDecimals={false} />
          <Tooltip />
          <Legend />
          <Line type="monotone" dataKey="created" stroke="#3b82f6" strokeWidth={2} name="Criados" dot={false} />
          <Line type="monotone" dataKey="completed" stroke="#10b981" strokeWidth={2} name="Concluidos" dot={false} />
          <Line type="monotone" dataKey="wo" stroke="#ef4444" strokeWidth={2} name="WOs" dot={false} />
        </LineChart>
      </ChartCard>

      <ChartCard title="Desafios por Clube" subtitle="Top 10">
        <BarChart data={byClub} layout="vertical">
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis type="number" tick={{ fontSize: 11 }} allowDecimals={false} />
          <YAxis dataKey="name" type="category" tick={{ fontSize: 10 }} width={80} />
          <Tooltip />
          <Bar dataKey="desafios" fill="#3b82f6" radius={[0, 4, 4, 0]} />
        </BarChart>
      </ChartCard>

      <ChartCard title="Distribuicao por Status">
        <PieChart>
          <Pie
            data={pieData}
            cx="50%"
            cy="50%"
            innerRadius={60}
            outerRadius={100}
            dataKey="value"
            nameKey="name"
            label={(props: PieLabelRenderProps) => `${props.name ?? ''} ${((props.percent ?? 0) * 100).toFixed(0)}%`}
            labelLine={false}
          >
            {pieData.map((_, i) => (
              <Cell key={i} fill={COLORS[i % COLORS.length]} />
            ))}
          </Pie>
          <Tooltip />
        </PieChart>
      </ChartCard>
    </div>
  )
}
