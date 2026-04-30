'use client'

import { useRouter } from 'next/navigation'
import { AddWineForm } from '@/app/components/wine/AddWineForm'
import { useAddWine, useUpdateWine, useWines } from '@/app/lib/hooks/useWines'
import { useCellarSelection } from '@/app/lib/hooks/useCellarSelection'
import { uploadWinePhoto } from '@/app/lib/photos/photoUtils'
import type { Wine } from '@/app/types'
import { useMemo } from 'react'

type WineFormData = Omit<Wine, 'id' | 'date_added'>

export default function AddWinePage() {
  const router = useRouter()
  const { selectedCellarId } = useCellarSelection()
  const addWine = useAddWine()
  const updateWine = useUpdateWine()
  const { data: wines = [] } = useWines(selectedCellarId)
  const existingZones = useMemo(
    () => [...new Set(wines.map(w => w.zone).filter(Boolean))].sort(),
    [wines]
  )

  async function handleSubmit(data: WineFormData, pendingPhoto?: File) {
    const cellarId = selectedCellarId ?? data.cellar_id
    if (!cellarId) {
      throw new Error('No cellar selected. Please go back and select a cellar first.')
    }
    const wine = await addWine.mutateAsync({
      ...data,
      cellar_id: cellarId,
    })

    // Upload photo now that we have a wine ID
    if (pendingPhoto) {
      try {
        const path = await uploadWinePhoto(pendingPhoto, wine.id)
        await updateWine.mutateAsync({ id: wine.id, photo_path: path })
      } catch (e) {
        // Wine was saved, photo failed — not critical
        console.error('Photo upload failed', e)
      }
    }

    router.replace(`/wines/${wine.id}`)
  }

  return (
    <div className="min-h-full">
      <div className="px-4 pt-12 pb-4 flex items-center gap-3">
        <button onClick={() => router.back()} className="text-gray-400 p-1">
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h1 className="text-xl font-bold text-gray-900">Add Wine</h1>
      </div>

      <div className="px-4 pb-nav">
        <AddWineForm
          initial={{ cellar_id: selectedCellarId ?? '' }}
          existingZones={existingZones}
          onSubmit={handleSubmit}
          submitLabel="Add Wine"
        />
      </div>
    </div>
  )
}
