interface EmptyStateProps {
  icon?: string
  title: string
  message: string
  action?: React.ReactNode
}

export function EmptyState({ icon = '🍷', title, message, action }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center py-20 px-8 text-center">
      <span className="text-5xl mb-4">{icon}</span>
      <h3 className="text-lg font-semibold text-gray-800 mb-1">{title}</h3>
      <p className="text-sm text-gray-500 mb-6">{message}</p>
      {action}
    </div>
  )
}
