'use client'

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { createClient } from '@/app/lib/supabase/client'
import type { Wine } from '@/app/types'

export function useWines(cellarId: string | null) {
  const supabase = createClient()

  return useQuery<Wine[]>({
    queryKey: ['wines', cellarId],
    queryFn: async () => {
      let query = supabase.from('wines').select('*')
      if (cellarId) query = query.eq('cellar_id', cellarId)
      query = query.order('date_added', { ascending: false })
      const { data, error } = await query
      if (error) throw error
      return data
    },
    enabled: !!cellarId,
  })
}

export function useWine(id: string) {
  const supabase = createClient()

  return useQuery<Wine>({
    queryKey: ['wine', id],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('wines')
        .select('*')
        .eq('id', id)
        .single()
      if (error) throw error
      return data
    },
    enabled: !!id,
  })
}

export function useAddWine() {
  const supabase = createClient()
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (wine: Omit<Wine, 'id' | 'date_added'>) => {
      const { data, error } = await supabase
        .from('wines')
        .insert(wine)
        .select()
        .single()
      if (error) throw error
      return data as Wine
    },
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: ['wines', data.cellar_id] })
    },
  })
}

export function useUpdateWine() {
  const supabase = createClient()
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async ({ id, ...updates }: Partial<Wine> & { id: string }) => {
      const { data, error } = await supabase
        .from('wines')
        .update(updates)
        .eq('id', id)
        .select()
        .single()
      if (error) throw error
      return data as Wine
    },
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: ['wines', data.cellar_id] })
      queryClient.invalidateQueries({ queryKey: ['wine', data.id] })
    },
  })
}

export function useDeleteWine() {
  const supabase = createClient()
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async ({ id, cellarId }: { id: string; cellarId: string }) => {
      const { error } = await supabase.from('wines').delete().eq('id', id)
      if (error) throw error
      return { id, cellarId }
    },
    onSuccess: ({ cellarId }) => {
      queryClient.invalidateQueries({ queryKey: ['wines', cellarId] })
    },
  })
}
