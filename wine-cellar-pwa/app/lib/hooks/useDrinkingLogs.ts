'use client'

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { createClient } from '@/app/lib/supabase/client'
import type { DrinkingLog } from '@/app/types'

export function useDrinkingLogs() {
  const supabase = createClient()

  return useQuery<DrinkingLog[]>({
    queryKey: ['drinking-logs'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('drinking_logs')
        .select('*')
        .order('date_consumed', { ascending: false })
      if (error) throw error
      return data
    },
  })
}

export function useLogDrinking() {
  const supabase = createClient()
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (log: Omit<DrinkingLog, 'id' | 'user_id' | 'date_consumed'>) => {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) throw new Error('Not authenticated')

      const { data, error } = await supabase
        .from('drinking_logs')
        .insert({ ...log, user_id: user.id })
        .select()
        .single()
      if (error) throw error
      return data as DrinkingLog
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['drinking-logs'] }),
  })
}
