'use client'

import { useEffect, useRef } from 'react'
import { createClient } from '@/app/lib/supabase/client'
import { useCellars, useCreateCellar } from './useCellars'
import { useCellarSelection } from './useCellarSelection'

export function useEnsureCellar() {
  const supabase = createClient()
  const { data: cellars = [], isLoading } = useCellars()
  const { selectedCellarId, setSelectedCellarId } = useCellarSelection()
  const createCellar = useCreateCellar()
  const didCreate = useRef(false)

  useEffect(() => {
    if (isLoading || cellars.length > 0 || didCreate.current) return

    async function create() {
      didCreate.current = true
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return

      // Derive a friendly name from email
      const emailName = user.email?.split('@')[0] ?? 'My'
      const name = `${emailName.charAt(0).toUpperCase() + emailName.slice(1)}'s Cellar`
      const ownerName = emailName.charAt(0).toUpperCase() + emailName.slice(1)

      try {
        const cellar = await createCellar.mutateAsync({ name, ownerName })
        setSelectedCellarId(cellar.id)
      } catch (e) {
        console.error('Failed to auto-create cellar', e)
      }
    }

    create()
  }, [isLoading, cellars.length])
}
