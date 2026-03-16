import { useState, useEffect, useCallback } from 'react';
import { fetchAllMarkets, fetchMarket, fetchMarketOutcome, fetchUserBet, fetchClaimStatus, calculateWinnings, type Market, type MarketOutcome, type Bet } from '../utils/contracts';
import { STACKS_API_URL } from '../utils/constants';

export function useMarkets() {
  const [markets, setMarkets] = useState<Market[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const load = useCallback(async () => {
    try { setLoading(true); setError(null); setMarkets(await fetchAllMarkets()); }
    catch { setError('Failed to load markets'); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { load(); const i = setInterval(load, 30_000); return () => clearInterval(i); }, [load]);
  return { markets, loading, error, refetch: load };
}

export function useMarket(marketId: number) {
  const [market, setMarket] = useState<Market | null>(null);
  const [outcomes, setOutcomes] = useState<MarketOutcome[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const load = useCallback(async () => {
    try {
      setLoading(true); setError(null);
      const m = await fetchMarket(marketId);
      if (!m) { setError('Market not found'); return; }
      setMarket(m);
      const outs = await Promise.all(Array.from({ length: m.outcomeCount }, (_, i) => fetchMarketOutcome(marketId, i)));
      setOutcomes(outs.filter(Boolean) as MarketOutcome[]);
    } catch { setError('Failed to load market'); }
    finally { setLoading(false); }
  }, [marketId]);
  useEffect(() => { load(); const i = setInterval(load, 15_000); return () => clearInterval(i); }, [load]);
  return { market, outcomes, loading, error, refetch: load };
}

export function useUserBets(marketId: number, userAddress: string | null, outcomeCount: number) {
  const [bets, setBets] = useState<(Bet | null)[]>([]);
  const [loading, setLoading] = useState(false);
  const load = useCallback(async () => {
    if (!userAddress) { setBets([]); return; }
    setLoading(true);
    try {
      const results = await Promise.all(Array.from({ length: outcomeCount }, (_, i) => fetchUserBet(marketId, userAddress, i)));
      setBets(results);
    } finally { setLoading(false); }
  }, [marketId, userAddress, outcomeCount]);
  useEffect(() => { load(); }, [load]);
  return { bets, loading, refetch: load };
}

export function useClaimInfo(marketId: number, userAddress: string | null, resolved: boolean) {
  const [claimStatus, setClaimStatus] = useState<{ claimed: boolean; amount: number } | null>(null);
  const [potentialWinnings, setPotentialWinnings] = useState(0);
  const [loading, setLoading] = useState(false);
  useEffect(() => {
    if (!userAddress || !resolved) return;
    setLoading(true);
    Promise.all([fetchClaimStatus(marketId, userAddress), calculateWinnings(marketId, userAddress)])
      .then(([status, winnings]) => { setClaimStatus(status); setPotentialWinnings(winnings); })
      .finally(() => setLoading(false));
  }, [marketId, userAddress, resolved]);
  return { claimStatus, potentialWinnings, loading };
}

export function useCurrentBlock() {
  const [currentBlock, setCurrentBlock] = useState(0);
  useEffect(() => {
    async function fetch() {
      try {
        const res = await window.fetch(`${STACKS_API_URL}/v2/info`);
        const data = await res.json();
        setCurrentBlock(data.stacks_tip_height || 0);
      } catch {}
    }
    fetch();
    const i = setInterval(fetch, 30_000);
    return () => clearInterval(i);
  }, []);
  return currentBlock;
}
// Hook for fetching markets created by a specific user
export function useUserCreatedMarkets(creatorAddress: string | null) {
  const { markets, loading, error, refetch } = useMarkets();
  const userMarkets = markets.filter(m => m.creator === creatorAddress);
  return { markets: userMarkets, loading, error, refetch };
}

// Hook for fetching only active (unresolved, before deadline) markets
export function useActiveMarkets() {
  const { markets, loading, error, refetch } = useMarkets();
  const currentBlock = useCurrentBlock();
  const activeMarkets = markets.filter(m => 
    !m.resolved && currentBlock < m.deadline
  );
  return { markets: activeMarkets, loading, error, refetch };
}

// Hook for fetching only resolved markets
export function useResolvedMarkets() {
  const { markets, loading, error, refetch } = useMarkets();
  const resolvedMarkets = markets.filter(m => m.resolved);
  return { markets: resolvedMarkets, loading, error, refetch };
}
```

**Commit message:**
```
feat: add useUserCreatedMarkets, useActiveMarkets, and useResolvedMarkets hooks
```

**PR Title:**
```
feat: add filtered market hooks for user, active, and resolved markets
```

**PR Description:**
```
## Summary
Adds three new custom React hooks that provide filtered views of market data 
for common UI use cases.

## New Hooks

### `useUserCreatedMarkets(creatorAddress)`
- Filters all markets to only those created by a specific address
- Used on the dashboard to show markets the user has created
- Returns same loading/error/refetch interface as useMarkets

### `useActiveMarkets()`
- Returns only markets that are unresolved and before their deadline
- Uses useCurrentBlock() to determine active status in real time
- Used for the Active filter tab on the market listing page

### `useResolvedMarkets()`
- Returns only markets where resolved is true
- Used for the Resolved filter tab on the market listing page

## Why
These hooks reduce repeated filtering logic across multiple page components 
and make the codebase easier to maintain.

## Files Changed
- `frontend/src/hooks/useMarkets.ts`
