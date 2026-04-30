'use client'

import Link from 'next/link'
import type { Wine } from '@/app/types'
import { WineThumbnail } from './WineThumbnail'

interface WineRowProps {
  wine: Wine
}

export function WineRow({ wine }: WineRowProps) {
  const label = [wine.variety, wine.producer].filter(Boolean).join(' · ')
  const vintage = wine.vintage > 0 ? wine.vintage : 'No Year'

  return (
    <Link href={`/wines/${wine.id}`} className="flex items-center gap-3 px-4 py-3 bg-white rounded-xl active:bg-gray-50">
      <WineThumbnail photoPath={wine.photo_path} name={wine.name} />
      <div className="flex-1 min-w-0">
        <div className="font-medium text-gray-900 truncate">
          {wine.name || wine.variety || 'Unnamed Wine'}
        </div>
        {label && (
          <div className="text-sm text-gray-500 truncate">{label}</div>
        )}
        <div className="flex items-center gap-2 mt-0.5">
          <span className="text-xs text-gray-400">{vintage}</span>
          {wine.region && <span className="text-xs text-gray-400">· {wine.region}</span>}
          {wine.quantity > 1 && (
            <span className="text-xs bg-[#7B2D42]/10 text-[#7B2D42] px-1.5 py-0.5 rounded-full font-medium">
              ×{wine.quantity}
            </span>
          )}
        </div>
      </div>
      <svg className="w-4 h-4 text-gray-300 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
      </svg>
    </Link>
  )
}
