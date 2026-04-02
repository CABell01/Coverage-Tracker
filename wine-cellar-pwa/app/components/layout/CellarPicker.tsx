'use client'

import { useState, useEffect } from 'react'
import { useCellars, useCreateCellar } from '@/app/lib/hooks/useCellars'
import { useCellarSelection } from '@/app/lib/hooks/useCellarSelection'
import { createClient } from '@/app/lib/supabase/client'

export function CellarPicker() {
  const { data: cellars = [] } = useCellars()
  const { selectedCellarId, setSelectedCellarId, setIsReadOnly } = useCellarSelection()
  const createCellar = useCreateCellar()

  const [showCreate, setShowCreate] = useState(false)
  const [newName, setNewName] = useState('')
  const [userId, setUserId] = useState<string | null>(null)

  useEffect(() => {
    createClient().auth.getUser().then(({ data }) => {
      setUserId(data.user?.id ?? null)
    })
  }, [])

  // Auto-select first cellar if none selected
  useEffect(() => {
    if (!selectedCellarId && cellars.length > 0) {
      setSelectedCellarId(cellars[0].id)
    }
  }, [cellars, selectedCellarId, setSelectedCellarId])

  // Update isReadOnly when selection changes
  useEffect(() => {
    if (!selectedCellarId || !userId) return
    const cellar = cellars.find(c => c.id === selectedCellarId)
    setIsReadOnly(cellar ? cellar.owner_id !== userId : false)
  }, [selectedCellarId, cellars, userId, setIsReadOnly])

  async function handleCreate() {
    const trimmed = newName.trim()
    if (!trimmed) return
    const { data: { user } } = await createClient().auth.getUser()
    const ownerName = user?.email?.split('@')[0] ?? 'Me'
    const cellar = await createCellar.mutateAsync({ name: trimmed, ownerName })
    setSelectedCellarId(cellar.id)
    setNewName('')
    setShowCreate(false)
  }

  return (
    <div className="px-4 py-2 space-y-2">
      <div className="flex gap-2 overflow-x-auto no-scrollbar">
        {cellars.map((cellar) => {
          const active = cellar.id === selectedCellarId
          const isOther = userId && cellar.owner_id !== userId
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
              {cellar.name}{isOther ? ` (${cellar.owner_name})` : ''}
            </button>
          )
        })}
        <button
          onClick={() => setShowCreate(true)}
          className="flex-shrink-0 w-8 h-8 rounded-full border border-dashed border-gray-300 flex items-center justify-center text-gray-400 hover:border-[#7B2D42] hover:text-[#7B2D42] transition-colors"
          title="New cellar"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
          </svg>
        </button>
      </div>

      {showCreate && (
        <div className="flex gap-2">
          <input
            type="text"
            value={newName}
            onChange={e => setNewName(e.target.value)}
            onKeyDown={e => e.key === 'Enter' && handleCreate()}
            placeholder="Cellar name..."
            className="flex-1 px-3 py-1.5 text-sm border border-gray-200 rounded-lg focus:outline-none focus:border-[#7B2D42]"
            autoFocus
          />
          <button
            onClick={handleCreate}
            disabled={!newName.trim() || createCellar.isPending}
            className="px-3 py-1.5 text-sm font-medium bg-[#7B2D42] text-white rounded-lg disabled:opacity-50"
          >
            {createCellar.isPending ? '...' : 'Add'}
          </button>
          <button
            onClick={() => { setShowCreate(false); setNewName('') }}
            className="px-2 py-1.5 text-sm text-gray-400"
          >
            Cancel
          </button>
        </div>
      )}
    </div>
  )
}
