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
