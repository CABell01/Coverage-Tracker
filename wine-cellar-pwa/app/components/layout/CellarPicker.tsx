'use client'

import { useCellars } from '@/app/lib/hooks/useCellars'
import { useCellarSelection } from '@/app/lib/hooks/useCellarSelection'
import { useEffect } from 'react'

export function CellarPicker() {
  const { data: cellars = [] } = useCellars()
  const { selectedCellarId, setSelectedCellarId } = useCellarSelection()

  // Auto-select first cellar if none selected
  useEffect(() => {
    if (!selectedCellarId && cellars.length > 0) {
      setSelectedCellarId(cellars[0].id)
    }
  }, [cellars, selectedCellarId, setSelectedCellarId])

  if (cellars.length === 0) return null

  return (
    <div className="flex gap-2 overflow-x-auto px-4 py-2 no-scrollbar">
      {cellars.map((cellar) => {
        const active = cellar.id === selectedCellarId
        return (
          <button
            key={cellar.id}
            onClick={() => setSelectedCellarId(cellar.id)}
            className={`flex-shrink-0 px-4 py-1.5 rounded-full text-sm font-medium transition-colors ${
              active
                ? 'bg-[#7B2D42] text-white'
                : 'bg-white text-gray-600 border border-gray-200'
            }`}
          >
            {cellar.name}
          </button>
        )
      })}
    </div>
  )
}
