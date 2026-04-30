import type { Wine } from '@/app/types'

interface ColumnMapping {
  name?: number
  producer?: number
  variety?: number
  region?: number
  country?: number
  vintage?: number
  zone?: number
  notes?: number
  drankIdx?: number
}

function parseLine(line: string, delimiter: string): string[] {
  const fields: string[] = []
  let current = ''
  let inQuotes = false
  for (const char of line) {
    if (char === '"') {
      inQuotes = !inQuotes
    } else if (char === delimiter && !inQuotes) {
      fields.push(current.trim())
      current = ''
    } else {
      current += char
    }
  }
  fields.push(current.trim())
  return fields
}

function autoMap(headers: string[]): ColumnMapping {
  const mapping: ColumnMapping = {}
  const normalized = headers.map(h =>
    h.replace(/\uFEFF/g, '').toLowerCase().trim()
  )

  for (let i = 0; i < normalized.length; i++) {
    const h = normalized[i]
    if (h.includes('maker') || h.includes('producer') || h.includes('winery') || h.includes('brand')) {
      mapping.producer = i
    } else if (h === 'wine') {
      mapping.variety = i
    } else if (h.includes('name') && !h.includes('zone')) {
      mapping.name = i
    } else if (h.includes('variety') || h.includes('varietal') || h.includes('grape')) {
      mapping.variety = mapping.variety ?? i
    } else if (h.includes('country')) {
      mapping.country = i
    } else if (h.includes('region') || h.includes('appellation')) {
      mapping.region = i
    } else if (h.includes('vintage') || h.includes('year')) {
      mapping.vintage = i
    } else if (h.includes('zone') || h.includes('location')) {
      mapping.zone = i
    } else if (h.includes('note')) {
      mapping.notes = i
    } else if (h.includes('drank') || h.includes('drunk') || h.includes('consumed')) {
      mapping.drankIdx = i
    }
  }
  return mapping
}

export interface ParsedCSV {
  wines: Omit<Wine, 'id' | 'date_added'>[]
  skipped: number
  total: number
}

export function parseCSV(content: string, cellarId: string): ParsedCSV {
  const clean = content.replace(/\uFEFF/g, '')
  const lines = clean.split(/\r?\n/).filter(l => l.trim())
  if (lines.length < 2) return { wines: [], skipped: 0, total: 0 }

  const delimiter = lines[0].includes('\t') ? '\t' : ','
  const headers = parseLine(lines[0], delimiter)
  const mapping = autoMap(headers)

  const wines: Omit<Wine, 'id' | 'date_added'>[] = []
  let skipped = 0
  const currentYear = new Date().getFullYear()

  for (let i = 1; i < lines.length; i++) {
    const values = parseLine(lines[i], delimiter)
    const get = (idx?: number) => idx !== undefined ? (values[idx] ?? '').trim() : ''

    // Skip consumed wines
    if (mapping.drankIdx !== undefined) {
      const drank = get(mapping.drankIdx).toLowerCase()
      if (drank === 'true' || drank === 'yes' || drank === '1') {
        skipped++
        continue
      }
    }

    const name = get(mapping.name)
    const producer = get(mapping.producer)
    const variety = get(mapping.variety)

    // Skip empty rows
    if (!name && !variety && !producer) { skipped++; continue }

    const vintageStr = get(mapping.vintage)
    const vintage = parseInt(vintageStr) || 0
    const validVintage = vintage >= 1900 && vintage <= currentYear ? vintage : 0

    wines.push({
      cellar_id: cellarId,
      name,
      producer,
      variety,
      region: get(mapping.region),
      country: get(mapping.country),
      vintage: validVintage,
      zone: get(mapping.zone),
      slot: 1,
      notes: get(mapping.notes),
      quantity: 1,
      photo_path: null,
    })
  }

  return { wines, skipped, total: lines.length - 1 }
}
