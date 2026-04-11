'use client'

import { useState, useRef } from 'react'
import { useRouter } from 'next/navigation'
import type { Wine } from '@/app/types'
import { varieties as VARIETIES, regions as REGIONS } from '@/app/lib/constants/wineData'
import { uploadWinePhoto } from '@/app/lib/photos/photoUtils'

type WineFormData = Omit<Wine, 'id' | 'date_added'>

interface AddWineFormProps {
  initial?: Partial<WineFormData>
  wineId?: string
  existingZones?: string[]
  onSubmit: (data: WineFormData, pendingPhoto?: File) => Promise<void>
  submitLabel?: string
}

export function AddWineForm({ initial, wineId, existingZones = [], onSubmit, submitLabel = 'Save' }: AddWineFormProps) {
  const router = useRouter()
  const fileRef = useRef<HTMLInputElement>(null)

  const [form, setForm] = useState<WineFormData>({
    cellar_id: initial?.cellar_id ?? '',
    name: initial?.name ?? '',
    producer: initial?.producer ?? '',
    variety: initial?.variety ?? '',
    region: initial?.region ?? '',
    country: initial?.country ?? '',
    vintage: initial?.vintage ?? 0,
    zone: initial?.zone ?? '',
    slot: initial?.slot ?? 1,
    notes: initial?.notes ?? '',
    quantity: initial?.quantity ?? 1,
    photo_path: initial?.photo_path ?? null,
  })

  const [pendingPhoto, setPendingPhoto] = useState<File | null>(null)
  const [photoPreview, setPhotoPreview] = useState<string | null>(null)
  const [uploading, setUploading] = useState(false)
  const [scanning, setScanning] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')

  const set = (key: keyof WineFormData, value: WineFormData[keyof WineFormData]) =>
    setForm(f => ({ ...f, [key]: value }))

  async function handlePhoto(file: File) {
    // Show preview immediately
    const previewUrl = URL.createObjectURL(file)
    setPhotoPreview(previewUrl)

    // If we have a wineId (editing), upload immediately
    if (wineId) {
      setUploading(true)
      try {
        const path = await uploadWinePhoto(file, wineId)
        set('photo_path', path)
      } catch (e) {
        setError('Photo upload failed')
      } finally {
        setUploading(false)
      }
    } else {
      // For new wines, store file to upload after creation
      setPendingPhoto(file)
    }

    // Run OCR to auto-fill fields
    setScanning(true)
    try {
      const { createWorker } = await import('tesseract.js')
      const worker = await createWorker('eng')
      const { data: { text } } = await worker.recognize(previewUrl)
      await worker.terminate()

      if (text.trim()) {
        autoFillFromOCR(text)
      }
    } catch (e) {
      // OCR failed silently — user can still fill manually
    } finally {
      setScanning(false)
    }
  }

  function autoFillFromOCR(text: string) {
    const fullText = text.toLowerCase()

    // Only fill from known lists — OCR on wine labels is noisy
    if (!form.variety) {
      const matchedVariety = VARIETIES.find(v =>
        v.length > 3 && fullText.includes(v.toLowerCase())
      )
      if (matchedVariety) set('variety', matchedVariety)
    }

    if (!form.region) {
      const matchedRegion = REGIONS.find(r =>
        r.length > 3 && fullText.includes(r.toLowerCase())
      )
      if (matchedRegion) set('region', matchedRegion)
    }

    // Only match clear 4-digit years
    if (!form.vintage) {
      const yearMatch = text.match(/\b(19[5-9]\d|20[0-2]\d)\b/)
      if (yearMatch) set('vintage', parseInt(yearMatch[1]))
    }
    // Don't auto-fill name — OCR text is too unreliable for wine labels
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setSaving(true)
    setError('')
    try {
      await onSubmit(form, pendingPhoto ?? undefined)
    } catch (e: any) {
      setError(e.message ?? 'Something went wrong')
    } finally {
      setSaving(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 text-sm rounded-xl p-3">
          {error}
        </div>
      )}

      {/* Photo */}
      <div className="flex justify-center">
        <button
          type="button"
          onClick={() => fileRef.current?.click()}
          className="w-24 h-24 rounded-2xl bg-gray-100 border-2 border-dashed border-gray-300 flex flex-col items-center justify-center text-gray-400 hover:border-[#7B2D42] transition-colors overflow-hidden"
        >
          {photoPreview || form.photo_path ? (
            <img
              src={photoPreview ?? ''}
              alt="Wine photo"
              className="w-full h-full object-cover"
            />
          ) : uploading || scanning ? (
            <span className="text-xs">{scanning ? 'Reading label...' : 'Uploading...'}</span>
          ) : (
            <>
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z" />
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M15 13a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
              <span className="text-xs mt-1">Add photo</span>
            </>
          )}
        </button>
        <input
          ref={fileRef}
          type="file"
          accept="image/*"
          capture="environment"
          className="hidden"
          onChange={e => e.target.files?.[0] && handlePhoto(e.target.files[0])}
        />
      </div>
      {scanning && (
        <p className="text-center text-xs text-gray-400">Reading label to auto-fill fields...</p>
      )}

      <Field label="Wine Name">
        <input
          value={form.name}
          onChange={e => set('name', e.target.value)}
          placeholder="e.g. Château Margaux"
          className="input"
        />
      </Field>

      <Field label="Producer / Winery">
        <input
          value={form.producer}
          onChange={e => set('producer', e.target.value)}
          placeholder="e.g. Château Margaux"
          className="input"
        />
      </Field>

      <Field label="Variety">
        <input
          value={form.variety}
          onChange={e => set('variety', e.target.value)}
          list="varieties-list"
          placeholder="e.g. Cabernet Sauvignon"
          className="input"
        />
        <datalist id="varieties-list">
          {VARIETIES.map(v => <option key={v} value={v} />)}
        </datalist>
      </Field>

      <div className="grid grid-cols-2 gap-3">
        <Field label="Vintage">
          <input
            type="number"
            value={form.vintage || ''}
            onChange={e => set('vintage', parseInt(e.target.value) || 0)}
            placeholder="e.g. 2019"
            min={1900}
            max={new Date().getFullYear()}
            className="input"
          />
        </Field>

        <Field label="Quantity">
          <input
            type="number"
            value={form.quantity}
            onChange={e => set('quantity', parseInt(e.target.value) || 1)}
            min={1}
            className="input"
          />
        </Field>
      </div>

      <Field label="Region / Appellation">
        <input
          value={form.region}
          onChange={e => set('region', e.target.value)}
          list="regions-list"
          placeholder="e.g. Napa Valley"
          className="input"
        />
        <datalist id="regions-list">
          {REGIONS.map(r => <option key={r} value={r} />)}
        </datalist>
      </Field>

      <Field label="Country">
        <input
          value={form.country}
          onChange={e => set('country', e.target.value)}
          placeholder="e.g. France"
          className="input"
        />
      </Field>

      <div className="grid grid-cols-2 gap-3">
        <Field label="Zone / Row">
          <input
            value={form.zone}
            onChange={e => set('zone', e.target.value)}
            list="zones-list"
            placeholder="e.g. Row 1, Rack A"
            className="input"
          />
          <datalist id="zones-list">
            {existingZones.map(z => <option key={z} value={z} />)}
          </datalist>
        </Field>

        <Field label="Slot / Position">
          <input
            type="number"
            value={form.slot}
            onChange={e => set('slot', parseInt(e.target.value) || 1)}
            min={1}
            placeholder="e.g. 1"
            className="input"
          />
        </Field>
      </div>

      <Field label="Notes">
        <textarea
          value={form.notes}
          onChange={e => set('notes', e.target.value)}
          placeholder="Any notes about this wine..."
          rows={3}
          className="input resize-none"
        />
      </Field>

      <div className="flex gap-3 pt-2">
        <button
          type="button"
          onClick={() => router.back()}
          className="flex-1 py-3 rounded-xl border border-gray-200 text-gray-600 font-medium text-sm"
        >
          Cancel
        </button>
        <button
          type="submit"
          disabled={saving || uploading}
          className="flex-1 py-3 rounded-xl bg-[#7B2D42] text-white font-medium text-sm disabled:opacity-50"
        >
          {saving ? 'Saving...' : submitLabel}
        </button>
      </div>
    </form>
  )
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="space-y-1">
      <label className="text-xs font-medium text-gray-500 uppercase tracking-wide">{label}</label>
      {children}
    </div>
  )
}
