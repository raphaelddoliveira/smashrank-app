interface StatusBadgeProps {
  label: string
  colorClass: string
}

export function StatusBadge({ label, colorClass }: StatusBadgeProps) {
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${colorClass}`}>
      {label}
    </span>
  )
}
