import { useState, useEffect } from 'react';
import { callReadOnlyFunction, cvToValue, uintCV } from '@stacks/transactions';
import { NETWORK, CONTRACT_ADDRESS, CONTRACT_NAME } from '../utils/constants';

export interface MarketStats {
  totalPool: number;
  outcomePools: number[];
  outcomePercents: number[];
  isResolved: boolean;
  winningOutcome: number | null;
}

export function useMarketStats(marketId: number | null): { stats: MarketStats | null; loading: boolean; error: string | null } {
  const [stats, setStats] = useState<MarketStats | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (marketId === null) return;
    setLoading(true);
    setError(null);

    async function fetchStats() {
      try {
        const result = await callReadOnlyFunction({
          contractAddress: CONTRACT_ADDRESS,
          contractName: CONTRACT_NAME,
          functionName: 'get-market',
          functionArgs: [uintCV(marketId!)],
          network: NETWORK,
          senderAddress: CONTRACT_ADDRESS,
        });

        const data = cvToValue(result) as Record<string, unknown>;
        if (!data) { setError('Market not found'); return; }

        const totalPool = Number(data['total-pool'] ?? 0);
        const outcomeCount = Number(data['outcome-count'] ?? 2);
        const outcomePools = Array.from({ length: outcomeCount }, () => 0); // populated separately
        const outcomePercents = outcomePools.map(p => totalPool > 0 ? (p / totalPool) * 100 : 0);

        setStats({
          totalPool,
          outcomePools,
          outcomePercents,
          isResolved: Boolean(data['resolved']),
          winningOutcome: data['resolved'] ? Number(data['winning-outcome']) : null,
        });
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Failed to fetch market stats');
      } finally {
        setLoading(false);
      }
    }

    fetchStats();
  }, [marketId]);

  return { stats, loading, error };
}
