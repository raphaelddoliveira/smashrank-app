'use client'

import { useRouter } from 'next/navigation'
import { DataTable } from '@/components/data-table'
import { formatDate } from '@/lib/utils/format'

interface Club {
  id: string
  name: string
  address_city: string | null
  address_state: string | null
  invite_code: string
  members: number
  sports: number
  courts: number
  challenges: number
  created_at: string
  [key: string]: unknown
}

export function ClubsTable({ clubs }: { clubs: Club[] }) {
  const router = useRouter()

  const columns = [
    { key: 'name', label: 'Nome' },
    {
      key: 'address_city',
      label: 'Cidade',
      render: (row: Club) =>
        row.address_city ? `${row.address_city}/${row.address_state}` : '-',
    },
    { key: 'members', label: 'Membros' },
    { key: 'sports', label: 'Esportes' },
    { key: 'courts', label: 'Quadras' },
    { key: 'challenges', label: 'Desafios' },
    { key: 'invite_code', label: 'Codigo' },
    {
      key: 'created_at',
      label: 'Criado em',
      render: (row: Club) => formatDate(row.created_at),
    },
  ]

  return (
    <DataTable
      columns={columns}
      data={clubs}
      searchKey="name"
      searchPlaceholder="Buscar clube..."
      exportFilename="clubes"
      onRowClick={(row) => router.push(`/clubs/${row.id}`)}
    />
  )
}
