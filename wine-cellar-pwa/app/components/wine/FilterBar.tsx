'use client'

interface FilterBarProps {
  search: string
  onSearch: (v: string) => void
  filter: string
  onFilter: (v: string) => void
  filterOptions: string[]
}

export function FilterBar({ search, onSearch, filter, onFilter, filterOptions }: FilterBarProps) {
  return (
    <div className="sticky top-0 z-10 bg-[#FAF7F4] pt-2 pb-2 space-y-2">
      {/* Search */}
      <div className="px-4">
        <div className="relative">
          <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
          <input
            type="search"
            value={search}
            onChange={e => onSearch(e.target.value)}
            placeholder="Search wines..."
            className="w-full pl-9 pr-4 py-2 bg-white rounded-xl border border-gray-200 text-sm focus:outline-none focus:border-[#7B2D42] placeholder-gray-400"
          />
        </div>
      </div>

      {/* Filter pills */}
      <div className="flex gap-2 overflow-x-auto px-4 pb-1 no-scrollbar">
        {['All', ...filterOptions].map((opt) => (
          <button
            key={opt}
            onClick={() => onFilter(opt === 'All' ? '' : opt)}
            className={`flex-shrink-0 px-3 py-1 rounded-full text-xs font-medium transition-colors ${
              (opt === 'All' ? filter === '' : filter === opt)
                ? 'bg-[#7B2D42] text-white'
                : 'bg-white text-gray-600 border border-gray-200'
            }`}
          >
            {opt}
          </button>
        ))}
      </div>
    </div>
  )
}
