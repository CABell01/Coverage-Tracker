'use client'

import { useState, useMemo } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { createClient } from '@/app/lib/supabase/client'
import { useRealtimeCellars } from '@/app/lib/hooks/useRealtimeWines'
import { useWines } from '@/app/lib/hooks/useWines'
import { useCellarSelection } from '@/app/lib/hooks/useCellarSelection'
import { useRealtimeWines } from '@/app/lib/hooks/useRealtimeWines'
import { CellarPicker } from '@/app/components/layout/CellarPicker'
import { FilterBar } from '@/app/components/wine/FilterBar'
import { WineRow } from '@/app/components/wine/WineRow'
import { EmptyState } from '@/app/components/ui/EmptyState'
import { useEnsureCellar } from '@/app/lib/hooks/useEnsureCellar'

export default function WinesPage() {
  const router = useRouter()
  useEnsureCellar()
  const { selectedCellarId, isReadOnly } = useCellarSelection()
  const { data: wines = [], isLoading } = useWines(selectedCellarId)
  useRealtimeWines(selectedCellarId)
  useRealtimeCellars()

  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState('')

  const varieties = useMemo(
    () => [...new Set(wines.map(w => w.variety).filter(Boolean))].sort(),
    [wines]
  )

  const filtered = useMemo(() => {
    let list = wines
    if (filter) list = list.filter(w => w.variety === filter)
    if (search) {
      const q = search.toLowerCase()
      list = list.filter(w =>
        w.name?.toLowerCase().includes(q) ||
        w.producer?.toLowerCase().includes(q) ||
        w.variety?.toLowerCase().includes(q) ||
        w.region?.toLowerCase().includes(q)
      )
    }
    return list
  }, [wines, filter, search])

  return (
    <div className="min-h-full">
      {/* Header */}
      <div className="px-4 pt-12 pb-2 flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">{isReadOnly ? 'Wines' : 'My Wines'}</h1>
        <div className="flex items-center gap-2">
          <button
            onClick={async () => {
              const supabase = createClient()
              await supabase.auth.signOut()
              router.push('/login')
              router.refresh()
            }}
            className="w-9 h-9 rounded-full bg-white border border-gray-200 flex items-center justify-center text-gray-400"
            title="Sign out"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
            </svg>
          </button>
          {!isReadOnly && (
            <>
              <Link
                href="/import"
                className="w-9 h-9 rounded-full bg-white border border-gray-200 flex items-center justify-center text-gray-500"
                title="Import CSV"
              >
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                </svg>
              </Link>
              <Link
                href="/wines/add"
                className="w-9 h-9 rounded-full bg-[#7B2D42] flex items-center justify-center text-white shadow-sm"
                title="Add wine"
              >
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                </svg>
              </Link>
            </>
          )}
        </div>
      </div>

      <CellarPicker />

      <FilterBar
        search={search}
        onSearch={setSearch}
        filter={filter}
        onFilter={setFilter}
        filterOptions={varieties}
      />

      <div className="px-4 pb-4 space-y-2">
        {isLoading ? (
          <div className="space-y-2">
            {[...Array(6)].map((_, i) => (
              <div key={i} className="h-20 bg-white rounded-xl animate-pulse" />
            ))}
          </div>
        ) : filtered.length === 0 ? (
          <EmptyState
            title={wines.length === 0 ? 'No wines yet' : 'No results'}
            message={wines.length === 0 ? 'Add your first bottle to get started.' : 'Try adjusting your search or filter.'}
            action={
              wines.length === 0 && !isReadOnly ? (
                <Link
                  href="/wines/add"
                  className="px-5 py-2 bg-[#7B2D42] text-white rounded-full text-sm font-medium"
                >
                  Add Wine
                </Link>
              ) : undefined
            }
          />
        ) : (
          <>
            <p className="text-xs text-gray-400 px-1">
              {filtered.length} {filtered.length === 1 ? 'bottle' : 'bottles'}
            </p>
            {filtered.map(wine => (
              <WineRow key={wine.id} wine={wine} />
            ))}
          </>
        )}
      </div>
    </div>
  )
}
