'use client'

import { useRouter } from 'next/navigation'
import { DataTable } from '@/components/data-table'
import { StatusBadge } from '@/components/status-badge'
import { formatDate } from '@/lib/utils/format'
import {
  playerStatusLabels,
  playerStatusColors,
  paymentStatusLabels,
  paymentStatusColors,
} from '@/lib/utils/constants'

interface User {
  id: string
  full_name: string
  email: string
  nickname: string | null
  role: string
  status: string
  fee_status: string
  clubCount: number
  created_at: string
  [key: string]: unknown
}

export function UsersTable({ users }: { users: User[] }) {
  const router = useRouter()

  const columns = [
    {
      key: 'full_name',
      label: 'Nome',
      render: (row: User) => (
        <div>
          <span className="font-medium text-gray-900">{row.full_name}</span>
          {row.role === 'admin' && (
            <span className="ml-2 text-xs bg-purple-100 text-purple-800 px-1.5 py-0.5 rounded-full">
              admin
            </span>
          )}
        </div>
      ),
    },
    { key: 'email', label: 'Email' },
    {
      key: 'status',
      label: 'Status',
      render: (row: User) => (
        <StatusBadge
          label={playerStatusLabels[row.status] ?? row.status}
          colorClass={playerStatusColors[row.status] ?? 'bg-gray-100 text-gray-800'}
        />
      ),
    },
    {
      key: 'fee_status',
      label: 'Pagamento',
      render: (row: User) => (
        <StatusBadge
          label={paymentStatusLabels[row.fee_status] ?? row.fee_status}
          colorClass={paymentStatusColors[row.fee_status] ?? 'bg-gray-100 text-gray-800'}
        />
      ),
    },
    { key: 'clubCount', label: 'Clubes' },
    {
      key: 'created_at',
      label: 'Cadastro',
      render: (row: User) => formatDate(row.created_at),
    },
  ]

  return (
    <DataTable
      columns={columns}
      data={users}
      searchKey="full_name"
      searchPlaceholder="Buscar usuario..."
      exportFilename="usuarios"
      onRowClick={(row) => router.push(`/users/${row.id}`)}
    />
  )
}
