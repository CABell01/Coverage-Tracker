'use client'

import { useState, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { parseCSV } from '@/app/lib/csv/csvImporter'
import { useAddWine } from '@/app/lib/hooks/useWines'
import { useCellarSelection } from '@/app/lib/hooks/useCellarSelection'
import { useEnsureCellar } from '@/app/lib/hooks/useEnsureCellar'
import { CellarPicker } from '@/app/components/layout/CellarPicker'

export default function ImportPage() {
  const router = useRouter()
  const fileRef = useRef<HTMLInputElement>(null)
  useEnsureCellar()
  const { selectedCellarId } = useCellarSelection()
  const addWine = useAddWine()

  const [state, setState] = useState<'idle' | 'preview' | 'importing' | 'done'>('idle')
  const [preview, setPreview] = useState<ReturnType<typeof parseCSV> | null>(null)
  const [csvContent, setCsvContent] = useState('')
  const [imported, setImported] = useState(0)
  const [error, setError] = useState('')
  const [failures, setFailures] = useState<string[]>([])

  async function handleFile(file: File) {
    if (!selectedCellarId) {
      setError('Please select a cellar first before importing wines.')
      return
    }
    const text = await file.text()
    setCsvContent(text)
    try {
      const result = parseCSV(text, selectedCellarId)
      setPreview(result)
      setError('')
      setState('preview')
    } catch (e: any) {
      setError(e.message || 'Failed to parse CSV file.')
    }
  }

  async function handleImport() {
    if (!preview || !selectedCellarId) return
    setState('importing')
    setError('')
    setFailures([])
    let count = 0
    const failed: string[] = []

    for (const wine of preview.wines) {
      try {
        await addWine.mutateAsync({ ...wine, cellar_id: selectedCellarId })
        count++
        setImported(count)
      } catch (e: any) {
        const label = wine.name || wine.variety || 'Unknown wine'
        failed.push(label)
        console.error('Failed to import wine', label, e)
      }
    }

    setFailures(failed)
    setState('done')
  }

  return (
    <div className="min-h-full">
      <div className="px-4 pt-12 pb-4 flex items-center gap-3">
        <button onClick={() => router.back()} className="text-gray-400 p-1">
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h1 className="text-xl font-bold text-gray-900">Import CSV</h1>
      </div>

      <CellarPicker />

      <div className="px-4 space-y-4">
        {error && (
          <div className="bg-red-50 border border-red-200 rounded-xl p-3">
            <p className="text-sm text-red-700">{error}</p>
          </div>
        )}

        {!selectedCellarId && state === 'idle' && (
          <div className="bg-amber-50 border border-amber-200 rounded-xl p-3">
            <p className="text-sm text-amber-800">No cellar selected. Please go back and select or create a cellar first.</p>
          </div>
        )}

        {state === 'idle' && (
          <>
            <div
              onClick={() => fileRef.current?.click()}
              className="border-2 border-dashed border-gray-300 rounded-2xl p-10 flex flex-col items-center gap-3 cursor-pointer hover:border-[#7B2D42] transition-colors"
            >
              <svg className="w-10 h-10 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
              <div className="text-center">
                <p className="font-medium text-gray-700">Choose a CSV file</p>
                <p className="text-sm text-gray-400 mt-1">Supports comma or tab-separated files</p>
              </div>
            </div>
            <input
              ref={fileRef}
              type="file"
              accept=".csv,.tsv,.txt"
              className="hidden"
              onChange={e => e.target.files?.[0] && handleFile(e.target.files[0])}
            />

            <div className="bg-amber-50 border border-amber-200 rounded-xl p-3">
              <p className="text-sm text-amber-800 font-medium mb-1">Expected columns:</p>
              <p className="text-xs text-amber-700 font-mono">Name, Maker/Producer, Wine/Variety, Vintage, Region, Country, Location/Zone, Notes, Drank?</p>
            </div>
          </>
        )}

        {state === 'preview' && preview && (
          <>
            <div className="bg-white rounded-xl p-4 space-y-2">
              <div className="flex justify-between text-sm">
                <span className="text-gray-500">Total rows</span>
                <span className="font-medium">{preview.total}</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-500">To import</span>
                <span className="font-medium text-green-600">{preview.wines.length}</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-500">Skipped (consumed or empty)</span>
                <span className="font-medium text-gray-400">{preview.skipped}</span>
              </div>
            </div>

            {preview.wines.length > 0 && (
              <div className="bg-white rounded-xl overflow-hidden">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide px-4 py-2 border-b border-gray-100">
                  Preview (first 5)
                </p>
                {preview.wines.slice(0, 5).map((wine, i) => (
                  <div key={i} className="px-4 py-2.5 border-b border-gray-100 last:border-0">
                    <p className="text-sm font-medium text-gray-900">
                      {wine.name || wine.variety || 'Unnamed'}
                    </p>
                    <p className="text-xs text-gray-400">
                      {[wine.producer, wine.variety, wine.vintage > 0 ? wine.vintage : null]
                        .filter(Boolean).join(' · ')}
                    </p>
                  </div>
                ))}
              </div>
            )}

            <div className="flex gap-3">
              <button
                onClick={() => setState('idle')}
                className="flex-1 py-3 rounded-xl border border-gray-200 text-gray-600 font-medium text-sm"
              >
                Choose Different File
              </button>
              <button
                onClick={handleImport}
                disabled={preview.wines.length === 0}
                className="flex-1 py-3 rounded-xl bg-[#7B2D42] text-white font-medium text-sm disabled:opacity-50"
              >
                Import {preview.wines.length} Wines
              </button>
            </div>
          </>
        )}

        {state === 'importing' && (
          <div className="flex flex-col items-center gap-4 py-10">
            <div className="w-12 h-12 border-2 border-[#7B2D42] border-t-transparent rounded-full animate-spin" />
            <p className="text-gray-600">Importing {imported} of {preview?.wines.length}...</p>
          </div>
        )}

        {state === 'done' && (
          <div className="flex flex-col items-center gap-4 py-10">
            <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center">
              <svg className="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <div className="text-center">
              <p className="text-lg font-semibold text-gray-900">Import Complete!</p>
              <p className="text-gray-500 mt-1">{imported} wines added to your cellar</p>
              {failures.length > 0 && (
                <p className="text-red-500 text-sm mt-1">
                  {failures.length} failed: {failures.slice(0, 3).join(', ')}
                  {failures.length > 3 && ` and ${failures.length - 3} more`}
                </p>
              )}
            </div>
            <button
              onClick={() => router.replace('/wines')}
              className="px-6 py-3 bg-[#7B2D42] text-white rounded-full font-medium"
            >
              View My Wines
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
