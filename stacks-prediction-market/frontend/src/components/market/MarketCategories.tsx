import { useState } from 'react';

export type Category = 'all' | 'crypto' | 'sports' | 'politics' | 'tech' | 'other';

const CATEGORIES: { id: Category; label: string; emoji: string }[] = [
  { id: 'all', label: 'All', emoji: '🌐' },
  { id: 'crypto', label: 'Crypto', emoji: '₿' },
  { id: 'sports', label: 'Sports', emoji: '⚽' },
  { id: 'politics', label: 'Politics', emoji: '🗳️' },
  { id: 'tech', label: 'Tech', emoji: '💻' },
  { id: 'other', label: 'Other', emoji: '📌' },
];

interface Props {
  selected: Category;
  onChange: (cat: Category) => void;
}

export default function MarketCategories({ selected, onChange }: Props) {
  return (
    <div className="flex gap-2 flex-wrap" role="tablist" aria-label="Market categories">
      {CATEGORIES.map(({ id, label, emoji }) => (
        <button
          key={id}
          role="tab"
          aria-selected={selected === id}
          onClick={() => onChange(id)}
          className={`px-3 py-1.5 rounded-full text-sm font-medium transition-colors border ${
            selected === id
              ? 'bg-blue-600 border-blue-500 text-white'
              : 'bg-gray-900 border-gray-700 text-gray-400 hover:border-gray-500 hover:text-white'
          }`}
        >
          {emoji} {label}
        </button>
      ))}
    </div>
  );
}
