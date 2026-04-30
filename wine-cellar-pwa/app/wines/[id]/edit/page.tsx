'use client'

import { useRouter, useParams } from 'next/navigation'
import { useWine, useUpdateWine, useWines } from '@/app/lib/hooks/useWines'
import { AddWineForm } from '@/app/components/wine/AddWineForm'
import type { Wine } from '@/app/types'
import { useMemo } from 'react'

type WineFormData = Omit<Wine, 'id' | 'date_added'>

export default function EditWinePage() {
  const router = useRouter()
  const { id } = useParams<{ id: string }>()
  const { data: wine, isLoading } = useWine(id)
  const updateWine = useUpdateWine()
  const { data: wines = [] } = useWines(wine?.cellar_id ?? null)
  const existingZones = useMemo(
    () => [...new Set(wines.map(w => w.zone).filter(Boolean))].sort(),
    [wines]
  )

  if (isLoading) {
    return (
      <div className="min-h-full flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-[#7B2D42] border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  if (!wine) return null

  async function handleSubmit(data: WineFormData) {
    await updateWine.mutateAsync({ id, ...data })
    router.replace(`/wines/${id}`)
  }

  return (
    <div className="min-h-full">
      <div className="px-4 pt-12 pb-4 flex items-center gap-3">
        <button onClick={() => router.back()} className="text-gray-400 p-1">
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h1 className="text-xl font-bold text-gray-900">Edit Wine</h1>
      </div>

      <div className="px-4 pb-nav">
        <AddWineForm
          initial={wine}
          wineId={wine.id}
          existingZones={existingZones}
          onSubmit={handleSubmit}
          submitLabel="Save Changes"
        />
      </div>
    </div>
  )
}
