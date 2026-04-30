'use client'

import { useDrinkingLogs } from '@/app/lib/hooks/useDrinkingLogs'
import { StarRating } from '@/app/components/ui/StarRating'
import { EmptyState } from '@/app/components/ui/EmptyState'

export default function HistoryPage() {
  const { data: logs = [], isLoading } = useDrinkingLogs()

  return (
    <div className="min-h-full">
      <div className="px-4 pt-12 pb-4">
        <h1 className="text-2xl font-bold text-gray-900">Drinking History</h1>
      </div>

      <div className="px-4 pb-4 space-y-2">
        {isLoading ? (
          <div className="space-y-2">
            {[...Array(4)].map((_, i) => (
              <div key={i} className="h-24 bg-white rounded-xl animate-pulse" />
            ))}
          </div>
        ) : logs.length === 0 ? (
          <EmptyState
            icon="📓"
            title="No history yet"
            message="Bottles you drink will be logged here."
          />
        ) : (
          logs.map(log => (
            <div key={log.id} className="bg-white rounded-xl p-4 space-y-1">
              <div className="flex items-start justify-between gap-2">
                <div className="flex-1 min-w-0">
                  <p className="font-medium text-gray-900 truncate">
                    {log.wine_name || log.variety || 'Unknown Wine'}
                  </p>
                  {log.producer && (
                    <p className="text-sm text-gray-500 truncate">{log.producer}</p>
                  )}
                  <div className="flex items-center gap-2 mt-0.5">
                    {log.vintage > 0 && (
                      <span className="text-xs text-gray-400">{log.vintage}</span>
                    )}
                    <span className="text-xs text-gray-400">
                      {new Date(log.date_consumed).toLocaleDateString('en-US', {
                        month: 'short', day: 'numeric', year: 'numeric'
                      })}
                    </span>
                  </div>
                </div>
                {log.rating > 0 && <StarRating value={log.rating} size="sm" />}
              </div>
              {log.tasting_notes && (
                <p className="text-sm text-gray-600 italic">"{log.tasting_notes}"</p>
              )}
            </div>
          ))
        )}
      </div>
    </div>
  )
}
