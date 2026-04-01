'use client'

import { createContext, useContext, useState, ReactNode } from 'react'

interface CellarSelectionContextType {
  selectedCellarId: string | null
  setSelectedCellarId: (id: string | null) => void
  isReadOnly: boolean
  setIsReadOnly: (val: boolean) => void
}

const CellarSelectionContext = createContext<CellarSelectionContextType>({
  selectedCellarId: null,
  setSelectedCellarId: () => {},
  isReadOnly: false,
  setIsReadOnly: () => {},
})

export function CellarSelectionProvider({ children }: { children: ReactNode }) {
  const [selectedCellarId, setSelectedCellarId] = useState<string | null>(null)
  const [isReadOnly, setIsReadOnly] = useState(false)

  return (
    <CellarSelectionContext.Provider
      value={{ selectedCellarId, setSelectedCellarId, isReadOnly, setIsReadOnly }}
    >
      {children}
    </CellarSelectionContext.Provider>
  )
}

export function useCellarSelection() {
  return useContext(CellarSelectionContext)
}
