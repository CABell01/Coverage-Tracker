'use client'

import { useMemo } from 'react'
import { useWines } from '@/app/lib/hooks/useWines'
import { useCellarSelection } from '@/app/lib/hooks/useCellarSelection'
import { useRealtimeWines } from '@/app/lib/hooks/useRealtimeWines'
import { CellarPicker } from '@/app/components/layout/CellarPicker'
import { ZoneWineRow } from '@/app/components/wine/ZoneWineRow'
import { EmptyState } from '@/app/components/ui/EmptyState'

export default function CellarPage() {
  const { selectedCellarId } = useCellarSelection()
  const { data: wines = [], isLoading } = useWines(selectedCellarId)
  useRealtimeWines(selectedCellarId)

  const byZone = useMemo(() => {
    const map: Record<string, typeof wines> = {}
    for (const wine of wines) {
      const zone = wine.zone || 'Unassigned'
      if (!map[zone]) map[zone] = []
      map[zone].push(wine)
    }
    // Sort wines within each zone by slot
    for (const zone in map) {
      map[zone].sort((a, b) => a.slot - b.slot)
    }
    return map
  }, [wines])

  const zones = Object.keys(byZone).sort((a, b) =>
    a === 'Unassigned' ? 1 : b === 'Unassigned' ? -1 : a.localeCompare(b)
  )

  const totalBottles = wines.reduce((sum, w) => sum + w.quantity, 0)

  return (
    <div className="min-h-full">
      <div className="px-4 pt-12 pb-2">
        <h1 className="text-2xl font-bold text-gray-900">Cellar Map</h1>
        {wines.length > 0 && (
          <p className="text-sm text-gray-500 mt-0.5">{totalBottles} bottles across {zones.length} zones</p>
        )}
      </div>

      <CellarPicker />

      <div className="px-4 pb-4 space-y-3 mt-2">
        {isLoading ? (
          <div className="space-y-3">
            {[...Array(3)].map((_, i) => (
              <div key={i} className="h-32 bg-white rounded-xl animate-pulse" />
            ))}
          </div>
        ) : zones.length === 0 ? (
          <EmptyState
            icon="🏚️"
            title="Cellar is empty"
            message="Add wines and assign them to zones to see your cellar map."
          />
        ) : (
          zones.map(zone => (
            <div key={zone} className="bg-white rounded-xl overflow-hidden">
              <div className="px-4 py-2.5 bg-[#7B2D42]/5 border-b border-[#7B2D42]/10">
                <div className="flex items-center justify-between">
                  <h2 className="font-semibold text-[#7B2D42]">Zone {zone}</h2>
                  <span className="text-xs text-gray-400">
                    {byZone[zone].reduce((s, w) => s + w.quantity, 0)} bottles
                  </span>
                </div>
              </div>
              <div className="px-4">
                {byZone[zone].map(wine => (
                  <ZoneWineRow key={wine.id} wine={wine} />
                ))}
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  )
}
