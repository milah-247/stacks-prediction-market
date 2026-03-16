import { useState, useMemo } from 'react';
import { type Market } from '../../utils/contracts';

interface MarketSearchProps {
  markets: Market[];
  onResults: (filtered: Market[]) => void;
}

export function MarketSearch({ markets, onResults }: MarketSearchProps) {
  const [query, setQuery] = useState('');
  const [sortBy, setSortBy] = useState<'newest' | 'oldest' | 'largest' | 'ending'>('newest');

  const filtered = useMemo(() => {
    let results = markets.filter(m =>
      m.title.toLowerCase().includes(query.toLowerCase()) ||
      m.description.toLowerCase().includes(query.toLowerCase())
    );

    switch (sortBy) {
      case 'newest':  results = results.sort((a, b) => b.createdAt - a.createdAt); break;
      case 'oldest':  results = results.sort((a, b) => a.createdAt - b.createdAt); break;
      case 'largest': results = results.sort((a, b) => b.totalPool - a.totalPool); break;
      case 'ending':  results = results.sort((a, b) => a.deadline - b.deadline); break;
    }

    onResults(results);
    return results;
  }, [markets, query, sortBy]);

  return (
    <div style={{ display: 'flex', gap: '12px', alignItems: 'center', flexWrap: 'wrap' }}>
      <div style={{ position: 'relative', flex: 1, minWidth: '200px' }}>
        <span style={{
          position: 'absolute', left: '12px', top: '50%',
          transform: 'translateY(-50%)', color: 'var(--text-muted)', fontSize: '14px'
        }}>🔍</span>
        <input
          type="text"
          className="input"
          placeholder="Search markets by title or description..."
          value={query}
          onChange={e => setQuery(e.target.value)}
          style={{ paddingLeft: '36px' }}
        />
      </div>
      <select
        value={sortBy}
        onChange={e => setSortBy(e.target.value as any)}
        style={{
          fontFamily: 'var(--font-mono)', fontSize: '12px', fontWeight: '700',
          background: 'var(--bg-secondary)', border: '1px solid var(--border-subtle)',
          borderRadius: 'var(--radius-sm)', color: 'var(--text-primary)',
          padding: '10px 14px', cursor: 'pointer', textTransform: 'uppercase',
          letterSpacing: '0.06em',
        }}
      >
        <option value="newest">Newest First</option>
        <option value="oldest">Oldest First</option>
        <option value="largest">Largest Pool</option>
        <option value="ending">Ending Soon</option>
      </select>
      {query && (
        <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
          {filtered.length} result{filtered.length !== 1 ? 's' : ''} for "{query}"
        </div>
      )}
    </div>
  );
}
