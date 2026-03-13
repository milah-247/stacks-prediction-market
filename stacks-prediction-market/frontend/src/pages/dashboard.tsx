import Head from 'next/head';
import Link from 'next/link';
import { useEffect, useState } from 'react';
import { useWalletStore } from '../hooks/useWallet';
import { useMarkets, useCurrentBlock } from '../hooks/useMarkets';
import { fetchUserBet, fetchClaimStatus, calculateWinnings, formatSTX, getMarketStatus, type Market } from '../utils/contracts';

interface UserMarketData {
  market: Market;
  bets: { outcomeIndex: number; amount: number; claimed: boolean; withdrawn: boolean }[];
  claimStatus: { claimed: boolean; amount: number } | null;
  potentialWinnings: number;
}

export default function DashboardPage() {
  const { connected, address } = useWalletStore();
  const { markets, loading: marketsLoading } = useMarkets();
  const currentBlock = useCurrentBlock();
  const [userMarkets, setUserMarkets] = useState<UserMarketData[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!address || markets.length === 0) return;
    setLoading(true);
    (async () => {
      const results: UserMarketData[] = [];
      for (const market of markets) {
        const rawBets = await Promise.all(Array.from({ length: market.outcomeCount }, (_, i) => fetchUserBet(market.id, address!, i)));
        const bets = rawBets.map((b, i) => b && b.amount > 0 ? { outcomeIndex: i, ...b } : null).filter(Boolean) as any[];
        if (bets.length > 0) {
          const [claimStatus, potentialWinnings] = await Promise.all([
            market.resolved ? fetchClaimStatus(market.id, address!) : Promise.resolve(null),
            market.resolved ? calculateWinnings(market.id, address!) : Promise.resolve(0),
          ]);
          results.push({ market, bets, claimStatus, potentialWinnings });
        }
      }
      setUserMarkets(results);
      setLoading(false);
    })();
  }, [address, markets]);

  if (!connected) return (
    <div className="container" style={{ padding: '80px 24px', textAlign: 'center' }}>
      <div style={{ fontSize: '48px', marginBottom: '16px' }}>⬡</div>
      <div style={{ fontFamily: 'var(--font-display)', fontSize: '28px', marginBottom: '12px' }}>Connect Your Wallet</div>
      <div style={{ color: 'var(--text-secondary)' }}>View your prediction market activity across all markets.</div>
    </div>
  );

  const totalBet = userMarkets.reduce((s, { bets }) => s + bets.reduce((b, bet) => b + bet.amount, 0), 0);
  const totalClaimable = userMarkets.reduce((s, { potentialWinnings }) => s + potentialWinnings, 0);
  const totalClaimed = userMarkets.filter(({ claimStatus }) => claimStatus?.claimed).reduce((s, { claimStatus }) => s + (claimStatus?.amount || 0), 0);

  return (
    <>
      <Head><title>Dashboard — Stacks Prediction Market</title></Head>
      <div className="container" style={{ padding: '48px 24px' }}>
        <div style={{ marginBottom: '40px' }}>
          <div style={{ fontSize: '11px', color: 'var(--accent-electric)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '8px' }}>Your Activity</div>
          <h1 style={{ fontFamily: 'var(--font-display)', fontWeight: '800', fontSize: '36px', letterSpacing: '-0.02em', marginBottom: '8px' }}>Dashboard</h1>
          <div style={{ color: 'var(--text-muted)', fontSize: '13px', fontFamily: 'var(--font-mono)' }}>{address?.slice(0, 8)}...{address?.slice(-6)}</div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '16px', marginBottom: '40px' }}>
          {[
            { label: 'Markets Entered', value: userMarkets.length.toString(), color: 'var(--accent-electric)' },
            { label: 'Active Bets', value: userMarkets.filter(({ market }) => !market.resolved).length.toString(), color: 'var(--accent-green)' },
            { label: 'Total Wagered', value: formatSTX(totalBet), color: 'var(--accent-gold)' },
            { label: 'Winnings Claimed', value: formatSTX(totalClaimed), color: 'var(--accent-green)' },
          ].map(({ label, value, color }) => (
            <div key={label} style={{ background: 'var(--bg-card)', border: '1px solid var(--border-subtle)', borderRadius: 'var(--radius-md)', padding: '20px' }}>
              <div style={{ fontSize: '10px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: '8px' }}>{label}</div>
              <div style={{ fontFamily: 'var(--font-display)', fontWeight: '800', fontSize: '22px', color }}>{value}</div>
            </div>
          ))}
        </div>

        {totalClaimable > 0 && (
          <div style={{ background: 'rgba(61, 214, 140, 0.08)', border: '1px solid rgba(61, 214, 140, 0.3)', borderRadius: 'var(--radius-md)', padding: '20px 24px', marginBottom: '32px' }}>
            <div style={{ fontFamily: 'var(--font-display)', fontWeight: '700', fontSize: '18px', color: 'var(--accent-green)' }}>🏆 {formatSTX(totalClaimable)} ready to claim</div>
            <div style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>You have unclaimed winnings on resolved markets</div>
          </div>
        )}

        {loading || marketsLoading ? (
          <div style={{ textAlign: 'center', padding: '60px', color: 'var(--text-muted)' }}>
            <div className="loading-pulse" style={{ fontSize: '32px', marginBottom: '12px' }}>⬡</div>
            <div>Loading your activity...</div>
          </div>
        ) : userMarkets.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '80px 0' }}>
            <div style={{ fontSize: '48px', marginBottom: '16px' }}>📊</div>
            <div style={{ fontFamily: 'var(--font-display)', fontSize: '22px', marginBottom: '8px' }}>No activity yet</div>
            <div style={{ color: 'var(--text-muted)', marginBottom: '24px' }}>You haven't placed any bets yet.</div>
            <Link href="/" className="btn btn-primary">Browse Markets</Link>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            {userMarkets.map(({ market, bets, claimStatus, potentialWinnings }) => {
              const hasUnclaimed = market.resolved && potentialWinnings > 0 && !claimStatus?.claimed;
              return (
                <div key={market.id} style={{ background: 'var(--bg-card)', border: `1px solid ${hasUnclaimed ? 'rgba(61, 214, 140, 0.3)' : 'var(--border-subtle)'}`, borderRadius: 'var(--radius-lg)', padding: '24px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '16px' }}>
                    <div style={{ flex: 1 }}>
                      <div style={{ fontSize: '10px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: '6px' }}>Market #{market.id} · {getMarketStatus(market, currentBlock)}</div>
                      <Link href={`/market/${market.id}`} style={{ textDecoration: 'none' }}>
                        <h3 style={{ fontFamily: 'var(--font-display)', fontWeight: '700', fontSize: '17px', color: 'var(--text-primary)', lineHeight: '1.3', cursor: 'pointer' }}>{market.title}</h3>
                      </Link>
                    </div>
                    {hasUnclaimed && <Link href={`/market/${market.id}`} className="btn btn-gold btn-sm" style={{ marginLeft: '16px', whiteSpace: 'nowrap' }}>Claim {formatSTX(potentialWinnings)}</Link>}
                    {claimStatus?.claimed && <span style={{ color: 'var(--accent-green)', fontSize: '13px', fontWeight: '700', marginLeft: '16px' }}>✓ Claimed {formatSTX(claimStatus.amount)}</span>}
                  </div>
                  <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                    {bets.map((bet: any) => (
                      <div key={bet.outcomeIndex} style={{ background: 'var(--bg-secondary)', border: `1px solid ${market.resolved && market.winningOutcome === bet.outcomeIndex ? 'rgba(61,214,140,0.4)' : 'var(--border-subtle)'}`, borderRadius: 'var(--radius-sm)', padding: '8px 12px', fontSize: '12px' }}>
                        <span style={{ fontWeight: '700' }}>Outcome {bet.outcomeIndex}</span>
                        <span style={{ color: 'var(--accent-gold)', marginLeft: '8px', fontWeight: '700' }}>{formatSTX(bet.amount)}</span>
                        {market.resolved && market.winningOutcome === bet.outcomeIndex && <span style={{ marginLeft: '6px' }}>🏆</span>}
                        {bet.withdrawn && <span style={{ color: 'var(--text-muted)', marginLeft: '6px', fontSize: '11px' }}>withdrawn</span>}
                      </div>
                    ))}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </>
  );
}
