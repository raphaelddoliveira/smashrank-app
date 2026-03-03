export const challengeStatusLabels: Record<string, string> = {
  pending: 'Pendente',
  dates_proposed: 'Datas Propostas',
  scheduled: 'Agendado',
  pending_result: 'Aguardando Resultado',
  completed: 'Concluido',
  wo_challenger: 'WO Desafiante',
  wo_challenged: 'WO Desafiado',
  expired: 'Expirado',
  cancelled: 'Cancelado',
}

export const challengeStatusColors: Record<string, string> = {
  pending: 'bg-yellow-100 text-yellow-800',
  dates_proposed: 'bg-blue-100 text-blue-800',
  scheduled: 'bg-indigo-100 text-indigo-800',
  pending_result: 'bg-orange-100 text-orange-800',
  completed: 'bg-green-100 text-green-800',
  wo_challenger: 'bg-red-100 text-red-800',
  wo_challenged: 'bg-red-100 text-red-800',
  expired: 'bg-gray-100 text-gray-800',
  cancelled: 'bg-gray-100 text-gray-800',
}

export const playerStatusLabels: Record<string, string> = {
  active: 'Ativo',
  inactive: 'Inativo',
  ambulance: 'Ambulancia',
  suspended: 'Suspenso',
}

export const playerStatusColors: Record<string, string> = {
  active: 'bg-green-100 text-green-800',
  inactive: 'bg-gray-100 text-gray-800',
  ambulance: 'bg-orange-100 text-orange-800',
  suspended: 'bg-red-100 text-red-800',
}

export const paymentStatusLabels: Record<string, string> = {
  paid: 'Pago',
  pending: 'Pendente',
  overdue: 'Inadimplente',
}

export const paymentStatusColors: Record<string, string> = {
  paid: 'bg-green-100 text-green-800',
  pending: 'bg-yellow-100 text-yellow-800',
  overdue: 'bg-red-100 text-red-800',
}
