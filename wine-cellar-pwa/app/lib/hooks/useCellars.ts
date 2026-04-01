'use client'

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { createClient } from '@/app/lib/supabase/client'
import type { Cellar } from '@/app/types'

export function useCellars() {
  const supabase = createClient()

  return useQuery<Cellar[]>({
    queryKey: ['cellars'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('cellars')
        .select('*')
        .order('last_updated', { ascending: false })
      if (error) throw error
      return data
    },
  })
}

export function useCreateCellar() {
  const supabase = createClient()
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async ({ name, ownerName }: { name: string; ownerName: string }) => {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) throw new Error('Not authenticated')

      const { data, error } = await supabase
        .from('cellars')
        .insert({ name, owner_name: ownerName, owner_id: user.id })
        .select()
        .single()
      if (error) throw error
      return data as Cellar
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['cellars'] }),
  })
}
