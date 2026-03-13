import { useState, useEffect } from 'react';
import Head from 'next/head';
import Link from 'next/link';
import { MarketCard } from '../components/market/MarketCard';
import { useMarkets } from '../hooks/useMarkets';
import { fetchMarketOutcome, type Market, type MarketOutcome } from '../utils/contracts';

function SkeletonCard() {
  return (
    <div className="card" style={{ pointerEvents: 'none' }}>
      <div className="skeleton" style={{ height: '12px', width: '80px', marginBottom: '16px' }} />
      <div className="skeleton" style={{ height: '24px', width: '85%', marginBottom: '8px' }} />
      <div className="skeleton" style={{ height: '8px', marginBottom: '20px' }} />
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '12px' }}>
        <div className="skeleton" style={{ height: '36px' }} />
        <div className="skeleton" style={{ height: '36px' }} />
        <div className="skeleton" style={{ height: '36px' }} />
      </div>
    </div>
  );
}

function useMarketsWithOutcomes(markets: Market[]) {
  const [outcomesMap, setOutcomesMap] = useState<Record<number, MarketOutcome[]>>({});
  useEffect(() => {
    if (markets.length === 0) return;
    Promise.all(markets.map(async m => {
      const outs = await Promise.all(Array.from({ length: m.outcomeCount }, (_, i) => fetchMarketOutcome(m.id, i)));
      return [m.id, outs.filter(Boolean) as MarketOutcome[]] as const;
    })).then(entries => setOutcomesMap(Object.fromEntries(entries)));
  }, [markets]);
  return outcomesMap;
}

type FilterType = 'all' | 'active' | 'resolved';

export default function HomePage() {
  const { markets, loading, error, refetch } = useMarkets();
  const outcomesMap = useMarketsWithOutcomes(markets);
  const [filter, setFilter] = useState<FilterType>('all');
  const [searchQuery, setSearchQuery] = useState('');

  const totalPool = markets.reduce((s, m) => s + m.totalPool, 0);
  const filtered = markets.filter(m => {
    const matchSearch = m.title.toLowerCase().includes(searchQuery.toLowerCase());
    const matchFilter = filter === 'all' || (filter === 'active' && !m.resolved) || (filter === 'resolved' && m.resolved);
    return matchSearch && matchFilter;
  });

  return (
    <>
      <Head><title>Stacks Prediction Market — Decentralized Forecasting</title></Head>
      <div className="container" style={{ padding: '48px 24px' }}>
        <div style={{ marginBottom: '48px', maxWidth: '640px' }}>
          <div style={{ fontSize: '11px', fontWeight: '700', textTransform: 'uppercase', letterSpacing: '0.15em', color: 'var(--accent-electric)', marginBottom: '16px' }}>⬡ On-Chain · Trustless · Permissionless</div>
          <h1 style={{ fontFamily: 'var(--font-display)', fontWeight: '800', fontSize: 'clamp(36px, 5vw, 60px)', lineHeight: '1.05', letterSpacing: '-0.03em', marginBottom: '20px', background: 'linear-gradient(135deg, var(--text-primary) 0%, var(--accent-electric) 100%)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent' }}>
            Predict the Future.<br />Win with Proof.
          </h1>
          <p style={{ fontSize: '16px', color: 'var(--text-secondary)', lineHeight: '1.7', marginBottom: '24px' }}>
            Decentralized prediction markets built on Stacks. Bet STX on real-world outcomes, governed entirely by Clarity smart contracts.
          </p>
          <Link href="/create" className="btn btn-primary btn-lg">+ Create Market</Link>
        </div>

        {!loading && markets.length > 0 && (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '16px', marginBottom: '48px' }}>
            {[
              { label: 'Total Markets', value: markets.length },
              { label: 'Active', value: markets.filter(m => !m.resolved).length },
              { label: 'Volume (STX)', value: (totalPool / 1_000_000).toFixed(1) },
              { label: 'Resolved', value: markets.filter(m => m.resolved).length },
            ].map(({ label, value }) => (
              <div key={label} style={{ background: 'var(--bg-card)', border: '1px solid var(--border-subtle)', borderRadius: 'var(--radius-md)', padding: '20px', textAlign: 'center' }}>
                <div style={{ fontFamily: 'var(--font-display)', fontWeight: '800', fontSize: '28px', color: 'var(--accent-electric)', marginBottom: '4px' }}>{value}</div>
                <div style={{ fontSize: '11px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em' }}>{label}</div>
              </div>
            ))}
          </div>
        )}

        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px', gap: '16px', flexWrap: 'wrap' }}>
          <div style={{ display: 'flex', gap: '8px' }}>
            {(['all', 'active', 'resolved'] as FilterType[]).map(f => (
              <button key={f} onClick={() => setFilter(f)} style={{ padding: '6px 14px', borderRadius: 'var(--radius-sm)', border: filter === f ? '1px solid var(--accent-electric)' : '1px solid var(--border-subtle)', background: filter === f ? 'rgba(91, 140, 247, 0.15)' : 'transparent', color: filter === f ? 'var(--accent-electric)' : 'var(--text-secondary)', cursor: 'pointer', fontSize: '12px', fontWeight: '700', textTransform: 'uppercase', letterSpacing: '0.06em', fontFamily: 'var(--font-mono)', transition: 'all 0.2s ease' }}>{f}</button>
            ))}
          </div>
          <input type="text" className="input" placeholder="Search markets..." value={searchQuery} onChange={e => setSearchQuery(e.target.value)} style={{ maxWidth: '280px' }} />
        </div>

        {error && (
          <div style={{ background: 'rgba(240, 85, 114, 0.1)', border: '1px solid rgba(240, 85, 114, 0.3)', borderRadius: 'var(--radius-md)', padding: '16px', color: 'var(--accent-red)', marginBottom: '24px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span>{error}</span>
            <button className="btn btn-secondary btn-sm" onClick={refetch}>Retry</button>
          </div>
        )}

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(340px, 1fr))', gap: '20px' }}>
          {loading ? Array.from({ length: 6 }).map((_, i) => <SkeletonCard key={i} />) : filtered.map(market => <MarketCard key={market.id} market={market} outcomes={outcomesMap[market.id] || []} />)}
        </div>

        {!loading && filtered.length === 0 && (
          <div style={{ textAlign: 'center', padding: '80px 0' }}>
            <div style={{ fontSize: '48px', marginBottom: '16px' }}>⬡</div>
            <div style={{ fontFamily: 'var(--font-display)', fontSize: '22px', marginBottom: '8px' }}>{searchQuery ? 'No markets found' : 'No markets yet'}</div>
            <div style={{ color: 'var(--text-muted)', marginBottom: '24px' }}>{searchQuery ? 'Try a different search' : 'Be the first to create a prediction market'}</div>
            {!searchQuery && <Link href="/create" className="btn btn-primary">Create First Market</Link>}
          </div>
        )}
      </div>
    </>
  );
}
