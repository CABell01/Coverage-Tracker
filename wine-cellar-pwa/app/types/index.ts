export interface Wine {
  id: string
  cellar_id: string
  name: string
  producer: string
  variety: string
  region: string
  country: string
  vintage: number
  zone: string
  slot: number
  notes: string
  date_added: string
  quantity: number
  photo_path: string | null
}

export interface Cellar {
  id: string
  name: string
  owner_name: string
  owner_id: string
  last_updated: string
}

export interface DrinkingLog {
  id: string
  user_id: string
  wine_name: string
  producer: string
  variety: string
  vintage: number
  date_consumed: string
  rating: number
  tasting_notes: string
}
