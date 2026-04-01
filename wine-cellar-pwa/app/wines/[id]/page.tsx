'use client'

import { useState } from 'react'
import { useRouter, useParams } from 'next/navigation'
import Image from 'next/image'
import Link from 'next/link'
import { useWine, useDeleteWine } from '@/app/lib/hooks/useWines'
import { getPhotoUrl } from '@/app/lib/photos/photoUtils'
import { DrinkWineSheet } from '@/app/components/wine/DrinkWineSheet'
import { StarRating } from '@/app/components/ui/StarRating'

export default function WineDetailPage() {
  const router = useRouter()
  const { id } = useParams<{ id: string }>()
  const { data: wine, isLoading } = useWine(id)
  const deleteWine = useDeleteWine()

  const [drinkOpen, setDrinkOpen] = useState(false)
  const [confirmDelete, setConfirmDelete] = useState(false)

  async function handleDelete() {
    if (!wine) return
    await deleteWine.mutateAsync({ id: wine.id, cellarId: wine.cellar_id })
    router.replace('/wines')
  }

  if (isLoading) {
    return (
      <div className="min-h-full flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-[#7B2D42] border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  if (!wine) {
    return (
      <div className="min-h-full flex items-center justify-center">
        <p className="text-gray-500">Wine not found</p>
      </div>
    )
  }

  const photoUrl = getPhotoUrl(wine.photo_path)

  return (
    <div className="min-h-full">
      {/* Hero */}
      <div className="relative h-64 bg-[#7B2D42]">
        {photoUrl ? (
          <Image src={photoUrl} alt={wine.name} fill className="object-cover" />
        ) : (
          <div className="absolute inset-0 flex items-center justify-center">
            <span className="text-8xl opacity-30">🍷</span>
          </div>
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent" />

        {/* Back button */}
        <button
          onClick={() => router.back()}
          className="absolute top-12 left-4 w-9 h-9 rounded-full bg-black/30 backdrop-blur-sm flex items-center justify-center text-white"
        >
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>

        {/* Edit button */}
        <Link
          href={`/wines/${wine.id}/edit`}
          className="absolute top-12 right-4 w-9 h-9 rounded-full bg-black/30 backdrop-blur-sm flex items-center justify-center text-white"
        >
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
          </svg>
        </Link>

        {/* Title */}
        <div className="absolute bottom-4 left-4 right-4 text-white">
          <h1 className="text-2xl font-bold leading-tight">
            {wine.name || wine.variety || 'Unnamed Wine'}
          </h1>
          {wine.producer && <p className="text-white/80 text-sm mt-0.5">{wine.producer}</p>}
        </div>
      </div>

      {/* Info cards */}
      <div className="px-4 py-4 space-y-3">
        <div className="grid grid-cols-2 gap-3">
          <InfoCard label="Variety" value={wine.variety || '—'} />
          <InfoCard label="Vintage" value={wine.vintage > 0 ? String(wine.vintage) : 'No Year'} />
          <InfoCard label="Region" value={wine.region || '—'} />
          <InfoCard label="Country" value={wine.country || '—'} />
          <InfoCard label="Zone" value={wine.zone || '—'} />
          <InfoCard label="Quantity" value={String(wine.quantity)} />
        </div>

        {wine.notes && (
          <div className="bg-white rounded-xl p-4">
            <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-2">Notes</p>
            <p className="text-sm text-gray-700 whitespace-pre-wrap">{wine.notes}</p>
          </div>
        )}

        {/* Actions */}
        <button
          onClick={() => setDrinkOpen(true)}
          className="w-full py-3 rounded-xl bg-[#7B2D42] text-white font-medium flex items-center justify-center gap-2"
        >
          <span>🥂</span> Log a Drink
        </button>

        {!confirmDelete ? (
          <button
            onClick={() => setConfirmDelete(true)}
            className="w-full py-3 rounded-xl border border-red-200 text-red-500 font-medium text-sm"
          >
            Delete Wine
          </button>
        ) : (
          <div className="bg-red-50 border border-red-200 rounded-xl p-3 space-y-2">
            <p className="text-sm text-red-700 text-center">Are you sure? This can't be undone.</p>
            <div className="flex gap-2">
              <button
                onClick={() => setConfirmDelete(false)}
                className="flex-1 py-2 rounded-lg border border-gray-200 text-gray-600 text-sm"
              >
                Cancel
              </button>
              <button
                onClick={handleDelete}
                className="flex-1 py-2 rounded-lg bg-red-600 text-white text-sm font-medium"
              >
                Delete
              </button>
            </div>
          </div>
        )}
      </div>

      <DrinkWineSheet
        wine={wine}
        open={drinkOpen}
        onClose={() => setDrinkOpen(false)}
        onDrank={() => router.replace('/wines')}
      />
    </div>
  )
}

function InfoCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="bg-white rounded-xl p-3">
      <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">{label}</p>
      <p className="text-sm font-semibold text-gray-900 mt-0.5">{value}</p>
    </div>
  )
}
