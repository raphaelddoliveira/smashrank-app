'use client'

import { Download } from 'lucide-react'
import { exportToCSV } from '@/lib/utils/export'

interface ExportButtonProps {
  data: Record<string, unknown>[]
  filename: string
  label?: string
}

export function ExportButton({ data, filename, label = 'Exportar CSV' }: ExportButtonProps) {
  return (
    <button
      onClick={() => exportToCSV(data, filename)}
      className="flex items-center gap-2 px-3 py-2 text-sm text-gray-600 hover:bg-gray-100 rounded-lg border transition-colors"
    >
      <Download size={16} />
      {label}
    </button>
  )
}
