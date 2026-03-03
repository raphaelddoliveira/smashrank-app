'use client'

import { ChartCard } from '@/components/chart-card'
import {
  BarChart,
  Bar,
  PieChart,
  Pie,
  Cell,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  type PieLabelRenderProps,
} from 'recharts'

const STATUS_COLORS: Record<string, string> = {
  Pago: '#10b981',
  Pendente: '#f59e0b',
  Inadimplente: '#ef4444',
}

interface Props {
  byMonth: { month: string; receita: number }[]
  byStatus: { paid: number; pending: number; overdue: number }
}

export function PaymentCharts({ byMonth, byStatus }: Props) {
  const pieData = [
    { name: 'Pago', value: byStatus.paid },
    { name: 'Pendente', value: byStatus.pending },
    { name: 'Inadimplente', value: byStatus.overdue },
  ].filter((d) => d.value > 0)

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <ChartCard title="Receita Mensal" subtitle="Ultimos 12 meses">
        <BarChart data={byMonth}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey="month" tick={{ fontSize: 11 }} />
          <YAxis tick={{ fontSize: 11 }} />
          <Tooltip formatter={(value) => `R$ ${value}`} />
          <Bar dataKey="receita" fill="#10b981" radius={[4, 4, 0, 0]} name="Receita" />
        </BarChart>
      </ChartCard>

      <ChartCard title="Status de Pagamentos">
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
            {pieData.map((entry) => (
              <Cell key={entry.name} fill={STATUS_COLORS[entry.name] ?? '#6b7280'} />
            ))}
          </Pie>
          <Tooltip />
        </PieChart>
      </ChartCard>
    </div>
  )
}
