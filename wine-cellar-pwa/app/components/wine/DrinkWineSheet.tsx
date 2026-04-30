'use client'

import { useState } from 'react'
import { Modal } from '@/app/components/ui/Modal'
import { StarRating } from '@/app/components/ui/StarRating'
import { useLogDrinking } from '@/app/lib/hooks/useDrinkingLogs'
import { useUpdateWine, useDeleteWine } from '@/app/lib/hooks/useWines'
import type { Wine } from '@/app/types'

interface DrinkWineSheetProps {
  wine: Wine
  open: boolean
  onClose: () => void
  onDrank?: () => void
}

export function DrinkWineSheet({ wine, open, onClose, onDrank }: DrinkWineSheetProps) {
  const [rating, setRating] = useState(0)
  const [notes, setNotes] = useState('')
  const [removing, setRemoving] = useState(false)

  const logDrinking = useLogDrinking()
  const updateWine = useUpdateWine()
  const deleteWine = useDeleteWine()

  async function handleDrank() {
    setRemoving(true)
    try {
      // Log the drinking event
      await logDrinking.mutateAsync({
        wine_name: wine.name,
        producer: wine.producer,
        variety: wine.variety,
        vintage: wine.vintage,
        rating,
        tasting_notes: notes,
      })

      // Decrement quantity or delete if last bottle
      if (wine.quantity > 1) {
        await updateWine.mutateAsync({ id: wine.id, quantity: wine.quantity - 1 })
      } else {
        await deleteWine.mutateAsync({ id: wine.id, cellarId: wine.cellar_id })
      }

      onDrank?.()
      onClose()
    } catch (e) {
      console.error(e)
    } finally {
      setRemoving(false)
    }
  }

  return (
    <Modal open={open} onClose={onClose} title="Log a Drink">
      <div className="space-y-4">
        <div className="bg-[#7B2D42]/5 rounded-xl p-3">
          <p className="font-semibold text-gray-900">{wine.name || wine.variety}</p>
          {wine.producer && <p className="text-sm text-gray-500">{wine.producer}</p>}
          {wine.vintage > 0 && <p className="text-sm text-gray-400">{wine.vintage}</p>}
        </div>

        <div>
          <label className="text-xs font-medium text-gray-500 uppercase tracking-wide block mb-2">
            Rating
          </label>
          <StarRating value={rating} onChange={setRating} />
        </div>

        <div>
          <label className="text-xs font-medium text-gray-500 uppercase tracking-wide block mb-1">
            Tasting Notes
          </label>
          <textarea
            value={notes}
            onChange={e => setNotes(e.target.value)}
            placeholder="How did it taste?"
            rows={3}
            className="input resize-none"
          />
        </div>

        <button
          onClick={handleDrank}
          disabled={removing}
          className="w-full py-3 rounded-xl bg-[#7B2D42] text-white font-medium disabled:opacity-50"
        >
          {removing ? 'Logging...' : 'Log & Remove from Cellar'}
        </button>
      </div>
    </Modal>
  )
}
