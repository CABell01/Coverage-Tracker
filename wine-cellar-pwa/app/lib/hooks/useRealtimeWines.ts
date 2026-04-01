'use client'

import { useEffect } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { createClient } from '@/app/lib/supabase/client'

export function useRealtimeWines(cellarId: string | null) {
  const queryClient = useQueryClient()
  const supabase = createClient()

  useEffect(() => {
    if (!cellarId) return

    const channel = supabase
      .channel(`wines-${cellarId}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'wines', filter: `cellar_id=eq.${cellarId}` },
        () => { queryClient.invalidateQueries({ queryKey: ['wines', cellarId] }) }
      )
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [cellarId, supabase, queryClient])
}

export function useRealtimeCellars() {
  const queryClient = useQueryClient()
  const supabase = createClient()

  useEffect(() => {
    const channel = supabase
      .channel('cellars')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'cellars' },
        () => { queryClient.invalidateQueries({ queryKey: ['cellars'] }) }
      )
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [supabase, queryClient])
}
