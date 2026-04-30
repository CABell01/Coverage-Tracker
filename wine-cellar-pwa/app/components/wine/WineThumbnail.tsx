'use client'

import Image from 'next/image'
import { getPhotoUrl } from '@/app/lib/photos/photoUtils'

interface WineThumbnailProps {
  photoPath: string | null
  name: string
  size?: number
}

export function WineThumbnail({ photoPath, name, size = 56 }: WineThumbnailProps) {
  const url = getPhotoUrl(photoPath)

  if (url) {
    return (
      <div
        className="rounded-xl overflow-hidden flex-shrink-0 bg-gray-100"
        style={{ width: size, height: size }}
      >
        <Image
          src={url}
          alt={name}
          width={size}
          height={size}
          className="object-cover w-full h-full"
        />
      </div>
    )
  }

  return (
    <div
      className="rounded-xl flex-shrink-0 bg-[#7B2D42]/10 flex items-center justify-center"
      style={{ width: size, height: size }}
    >
      <span className="text-[#7B2D42]" style={{ fontSize: size * 0.45 }}>🍷</span>
    </div>
  )
}
