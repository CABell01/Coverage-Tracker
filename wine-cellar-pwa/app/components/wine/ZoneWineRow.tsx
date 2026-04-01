import Link from 'next/link'
import type { Wine } from '@/app/types'

interface ZoneWineRowProps {
  wine: Wine
}

export function ZoneWineRow({ wine }: ZoneWineRowProps) {
  const vintage = wine.vintage > 0 ? wine.vintage : 'No Year'
  return (
    <Link
      href={`/wines/${wine.id}`}
      className="flex items-center gap-3 py-2.5 border-b border-gray-100 last:border-0 active:bg-gray-50"
    >
      <div className="w-8 h-8 rounded-lg bg-[#7B2D42]/10 flex items-center justify-center flex-shrink-0">
        <span className="text-xs font-bold text-[#7B2D42]">{wine.slot}</span>
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-gray-900 truncate">
          {wine.name || wine.variety || 'Unnamed'}
        </p>
        <p className="text-xs text-gray-400 truncate">
          {[wine.producer, String(vintage)].filter(Boolean).join(' · ')}
        </p>
      </div>
      {wine.quantity > 1 && (
        <span className="text-xs bg-[#7B2D42]/10 text-[#7B2D42] px-2 py-0.5 rounded-full font-medium flex-shrink-0">
          ×{wine.quantity}
        </span>
      )}
    </Link>
  )
}
