import { useRouter } from 'next/router';
import Head from 'next/head';
import { openContractCall } from '@stacks/connect';
import { useMarket, useCurrentBlock } from '../../hooks/useMarkets';
import { BetPanel } from '../../components/market/BetPanel';
import { useWalletStore } from '../../hooks/useWallet';
import { formatSTX, getMarketStatus, getOutcomePercentage, buildResolveMarketTx } from '../../utils/contracts';
import { useState } from 'react';

export default function MarketDetailPage() {
  const router = useRouter();
  const { id } = router.query;
  const marketId = parseInt(id as string);
  const { market, outcomes, loading, error, refetch } = useMarket(marketId);
  const currentBlock = useCurrentBlock();
  const { address } = useWalletStore();
  const [resolving, setResolving] = useState(false);
  const [resolveMessage, setResolveMessage] = useState('');

  if (loading) return (
    <div className="container" style={{ padding: '48px 24px' }}>
      <div style={{ maxWidth: '1000px', margin: '0 auto' }}>
        <div className="skeleton" style={{ height: '32px', width: '200px', marginBottom: '24px' }} />
        <div className="skeleton" style={{ height: '48px', width: '80%', marginBottom: '48px' }} />
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 360px', gap: '24px' }}>
          <div className="skeleton" style={{ height: '400px', borderRadius: 'var(--radius-lg)' }} />
          <div className="skeleton" style={{ height: '400px', borderRadius: 'var(--radius-lg)' }} />
        </div>
      </div>
    </div>
  );

  if (error || !market) return (
    <div className="container" style={{ padding: '48px 24px', textAlign: 'center' }}>
      <div style={{ fontSize: '48px', marginBottom: '16px' }}>⚠</div>
      <div style={{ fontFamily: 'var(--font-display)', fontSize: '22px', marginBottom: '8px' }}>{error || 'Market not found'}</div>
      <button className="btn btn-secondary" onClick={() => router.push('/')}>← Back to Markets</button>
    </div>
  );

  const status = getMarketStatus(market, currentBlock);
  const blocksLeft = market.deadline - currentBlock;
  const daysLeft = Math.floor(Math.max(0, blocksLeft) / 144);
  const hoursLeft = Math.floor((Math.max(0, blocksLeft) % 144) / 6);
  const canResolve = (address === market.creator) && !market.resolved && currentBlock >= market.deadline;

  async function handleResolve(winningOutcome: number) {
    setResolving(true);
    try {
      await openContractCall({ ...buildResolveMarketTx(market!.id, winningOutcome), onFinish: (data: any) => { setResolveMessage(`Resolved! TX: ${data.txId.slice(0, 12)}...`); setTimeout(refetch, 3000); }, onCancel: () => setResolving(false) });
    } catch { setResolveMessage('Resolution failed.'); } finally { setResolving(false); }
  }

  const statusColors: Record<string, string> = { 'Active': 'var(--accent-green)', 'Resolved': 'var(--accent-electric)', 'Disputed': 'var(--accent-red)', 'Awaiting Resolution': 'var(--accent-gold)', 'Betting Closed': 'var(--text-muted)' };

  return (
    <>
      <Head><title>{market.title} — Stacks PM</title></Head>
      <div className="container" style={{ padding: '48px 24px' }}>
        <div style={{ maxWidth: '1000px', margin: '0 auto' }}>
          <button onClick={() => router.push('/')} style={{ background: 'none', border: 'none', color: 'var(--text-muted)', fontSize: '13px', cursor: 'pointer', marginBottom: '24px', display: 'flex', alignItems: 'center', gap: '6px', fontFamily: 'var(--font-mono)' }}>← All Markets</button>
          <div style={{ marginBottom: '40px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '12px' }}>
              <div style={{ fontSize: '11px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.1em' }}>MARKET #{market.id}</div>
              <div style={{ fontSize: '11px', fontWeight: '700', color: statusColors[status] || 'var(--text-muted)', textTransform: 'uppercase' }}>● {status}</div>
              {market.oracleResolved && <div style={{ fontSize: '11px', color: 'var(--accent-purple)', fontWeight: '700' }}>⬡ Oracle Verified</div>}
            </div>
            <h1 style={{ fontFamily: 'var(--font-display)', fontWeight: '800', fontSize: 'clamp(24px, 4vw, 40px)', letterSpacing: '-0.02em', lineHeight: '1.1', marginBottom: '16px' }}>{market.title}</h1>
            <p style={{ color: 'var(--text-secondary)', fontSize: '15px', lineHeight: '1.7', maxWidth: '640px' }}>{market.description}</p>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 360px', gap: '24px', alignItems: 'start' }}>
            <div>
              <div className="card" style={{ marginBottom: '20px' }}>
                <div style={{ fontFamily: 'var(--font-display)', fontWeight: '700', fontSize: '16px', marginBottom: '20px' }}>Current Odds</div>
                {outcomes.map((outcome, i) => {
                  const pct = getOutcomePercentage(outcome.pool, market.totalPool);
                  const colors = ['var(--accent-green)', 'var(--accent-red)', 'var(--accent-purple)'];
                  const color = colors[i % colors.length];
                  return (
                    <div key={i} style={{ marginBottom: '12px' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                          <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: color }} />
                          <span style={{ fontWeight: '700' }}>{outcome.label}</span>
                        </div>
                        <div style={{ display: 'flex', gap: '16px', alignItems: 'center' }}>
                          <span style={{ color: 'var(--text-muted)', fontSize: '13px' }}>{formatSTX(outcome.pool)}</span>
                          <span style={{ fontFamily: 'var(--font-display)', fontWeight: '800', fontSize: '18px', color }}>{pct}%</span>
                        </div>
                      </div>
                      <div style={{ height: '10px', background: 'var(--bg-secondary)', borderRadius: '100px', overflow: 'hidden' }}>
                        <div style={{ height: '100%', width: `${pct}%`, background: `linear-gradient(90deg, ${color}, ${color}88)`, borderRadius: '100px', transition: 'width 0.8s ease' }} />
                      </div>
                    </div>
                  );
                })}
                <hr className="divider" />
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '16px' }}>
                  {[
                    { label: 'Total Pool', value: formatSTX(market.totalPool), color: 'var(--accent-gold)' },
                    { label: 'Deadline Block', value: `#${market.deadline.toLocaleString()}`, color: 'var(--text-primary)' },
                    { label: 'Time Left', value: market.resolved ? '—' : blocksLeft > 0 ? `${daysLeft}d ${hoursLeft}h` : 'Ended', color: 'var(--text-primary)' },
                  ].map(({ label, value, color }) => (
                    <div key={label}>
                      <div style={{ fontSize: '10px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: '4px' }}>{label}</div>
                      <div style={{ fontFamily: 'var(--font-display)', fontWeight: '700', fontSize: '16px', color }}>{value}</div>
                    </div>
                  ))}
                </div>
              </div>

              {market.resolved && outcomes[market.winningOutcome] && (
                <div className="card" style={{ borderColor: 'rgba(61,214,140,0.4)', background: 'rgba(61,214,140,0.05)' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    <div style={{ fontSize: '32px' }}>🏆</div>
                    <div>
                      <div style={{ fontSize: '11px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: '4px' }}>Winning Outcome</div>
                      <div style={{ fontFamily: 'var(--font-display)', fontWeight: '800', fontSize: '22px', color: 'var(--accent-green)' }}>{outcomes[market.winningOutcome].label}</div>
                    </div>
                  </div>
                </div>
              )}

              {canResolve && (
                <div className="card" style={{ marginTop: '20px', borderColor: 'rgba(240,192,64,0.3)' }}>
                  <div style={{ fontFamily: 'var(--font-display)', fontWeight: '700', fontSize: '16px', marginBottom: '16px', color: 'var(--accent-gold)' }}>⚡ Resolve Market</div>
                  <div style={{ color: 'var(--text-secondary)', fontSize: '13px', marginBottom: '16px' }}>Select the winning outcome:</div>
                  <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                    {outcomes.map((o, i) => <button key={i} className="btn btn-gold" onClick={() => handleResolve(i)} disabled={resolving}>{o.label} Wins</button>)}
                  </div>
                  {resolveMessage && <div style={{ marginTop: '12px', fontSize: '13px', color: 'var(--accent-electric)' }}>{resolveMessage}</div>}
                </div>
              )}
            </div>

            <div style={{ position: 'sticky', top: '80px' }}>
              <BetPanel market={market} outcomes={outcomes} onSuccess={refetch} />
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
