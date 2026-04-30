'use client'

import { useState, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { useCellarSelection } from '@/app/lib/hooks/useCellarSelection'
import { useAddWine } from '@/app/lib/hooks/useWines'

export default function ScanPage() {
  const router = useRouter()
  const fileRef = useRef<HTMLInputElement>(null)
  const { selectedCellarId } = useCellarSelection()
  const addWine = useAddWine()

  const [scanning, setScanning] = useState(false)
  const [result, setResult] = useState<string | null>(null)

  async function handleImage(file: File) {
    setScanning(true)
    setResult(null)

    try {
      const { createWorker } = await import('tesseract.js')
      const worker = await createWorker('eng')
      const url = URL.createObjectURL(file)
      const { data: { text } } = await worker.recognize(url)
      URL.revokeObjectURL(url)
      await worker.terminate()
      setResult(text)
    } catch (e: any) {
      setResult('Could not read label. Try a clearer photo.')
    } finally {
      setScanning(false)
    }
  }

  return (
    <div className="min-h-full">
      <div className="px-4 pt-12 pb-4 flex items-center gap-3">
        <button onClick={() => router.back()} className="text-gray-400 p-1">
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h1 className="text-xl font-bold text-gray-900">Scan Label</h1>
      </div>

      <div className="px-4 space-y-4">
        <div
          onClick={() => !scanning && fileRef.current?.click()}
          className="border-2 border-dashed border-gray-300 rounded-2xl p-10 flex flex-col items-center gap-3 cursor-pointer hover:border-[#7B2D42] transition-colors"
        >
          {scanning ? (
            <>
              <div className="w-10 h-10 border-2 border-[#7B2D42] border-t-transparent rounded-full animate-spin" />
              <p className="text-gray-500">Reading label...</p>
            </>
          ) : (
            <>
              <svg className="w-10 h-10 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z" />
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M15 13a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
              <div className="text-center">
                <p className="font-medium text-gray-700">Take or upload a label photo</p>
                <p className="text-sm text-gray-400 mt-1">OCR will read the text for you</p>
              </div>
            </>
          )}
        </div>

        <input
          ref={fileRef}
          type="file"
          accept="image/*"
          capture="environment"
          className="hidden"
          onChange={e => e.target.files?.[0] && handleImage(e.target.files[0])}
        />

        {result && (
          <div className="bg-white rounded-xl p-4 space-y-2">
            <p className="text-xs font-medium text-gray-500 uppercase tracking-wide">Detected Text</p>
            <p className="text-sm text-gray-700 whitespace-pre-wrap font-mono">{result}</p>
            <button
              onClick={() => router.push('/wines/add')}
              className="w-full py-2.5 bg-[#7B2D42] text-white rounded-xl text-sm font-medium mt-2"
            >
              Add Wine Manually
            </button>
          </div>
        )}

        <div className="bg-amber-50 border border-amber-200 rounded-xl p-3">
          <p className="text-sm text-amber-800">
            <span className="font-medium">Tip:</span> For best results, photograph the label in good lighting against a flat background.
          </p>
        </div>
      </div>
    </div>
  )
}
