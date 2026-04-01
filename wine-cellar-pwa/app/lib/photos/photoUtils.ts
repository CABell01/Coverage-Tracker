import { createClient } from '@/app/lib/supabase/client'

export async function resizeAndCompress(file: File | Blob): Promise<Blob> {
  return new Promise((resolve) => {
    const img = new Image()
    const url = URL.createObjectURL(file)
    img.onload = () => {
      URL.revokeObjectURL(url)
      const maxDim = 800
      const scale = Math.min(1, maxDim / Math.max(img.width, img.height))
      const canvas = document.createElement('canvas')
      canvas.width = Math.round(img.width * scale)
      canvas.height = Math.round(img.height * scale)
      const ctx = canvas.getContext('2d')!
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height)
      canvas.toBlob((blob) => resolve(blob!), 'image/jpeg', 0.7)
    }
    img.src = url
  })
}

export async function uploadWinePhoto(
  file: File | Blob,
  wineId: string
): Promise<string> {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Not authenticated')

  const compressed = await resizeAndCompress(file)
  const path = `${user.id}/${wineId}.jpg`

  const { error } = await supabase.storage
    .from('wine-photos')
    .upload(path, compressed, { contentType: 'image/jpeg', upsert: true })

  if (error) throw error
  return path
}

export function getPhotoUrl(path: string | null): string | null {
  if (!path) return null
  const supabase = createClient()
  const { data } = supabase.storage.from('wine-photos').getPublicUrl(path)
  return data.publicUrl
}
