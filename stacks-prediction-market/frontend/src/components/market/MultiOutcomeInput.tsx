import { useState } from 'react';

interface MultiOutcomeInputProps {
  outcomes: string[];
  onChange: (outcomes: string[]) => void;
  max?: number;
}

/**
 * Allows users to add/remove outcome options (up to `max`, default 5).
 * Minimum 2 outcomes always required.
 */
export default function MultiOutcomeInput({ outcomes, onChange, max = 5 }: MultiOutcomeInputProps) {
  function update(index: number, value: string) {
    const next = [...outcomes];
    next[index] = value;
    onChange(next);
  }

  function add() {
    if (outcomes.length < max) onChange([...outcomes, '']);
  }

  function remove(index: number) {
    if (outcomes.length <= 2) return;
    onChange(outcomes.filter((_, i) => i !== index));
  }

  return (
    <div className="space-y-2">
      {outcomes.map((o, i) => (
        <div key={i} className="flex items-center gap-2">
          <span className="text-gray-400 text-sm w-6">{i + 1}.</span>
          <input
            className="flex-1 bg-gray-800 border border-gray-700 rounded px-3 py-2 text-sm text-white focus:outline-none focus:border-indigo-500"
            placeholder={`Outcome ${i + 1}`}
            value={o}
            onChange={(e) => update(i, e.target.value)}
            maxLength={64}
            aria-label={`Outcome ${i + 1}`}
          />
          {outcomes.length > 2 && (
            <button
              type="button"
              onClick={() => remove(i)}
              className="text-red-400 hover:text-red-300 text-lg leading-none"
              aria-label={`Remove outcome ${i + 1}`}
            >
              ×
            </button>
          )}
        </div>
      ))}
      {outcomes.length < max && (
        <button
          type="button"
          onClick={add}
          className="text-indigo-400 hover:text-indigo-300 text-sm mt-1"
        >
          + Add outcome
        </button>
      )}
    </div>
  );
}
