import Link from 'next/link';
import { type Market, type MarketOutcome, formatSTX, getMarketStatus, getOutcomePercentage, isMarketBettingOpen } from '../../utils/contracts';
import { useCurrentBlock } from '../../hooks/useMarkets';

function StatusBadge({ status }: { status: string }) {
  const cls: Record<string, string> = { 'Active': 'badge-active', 'Resolved': 'badge-resolved', 'Disputed': 'badge-disputed', 'Awaiting Resolution': 'badge-closed', 'Betting Closed': 'badge-closed' };
  const dot: Record<string, string> = { 'Active': '●', 'Resolved': '✓', 'Disputed': '!', 'Awaiting Resolution': '◌', 'Betting Closed': '⏸' };
  return <span className={`badge ${cls[status] || 'badge-closed'}`}>{dot[status] || '●'} {status}</span>;
}

export function MarketCard({ market, outcomes }: { market: Market; outcomes: MarketOutcome[] }) {
  const currentBlock = useCurrentBlock();
  const status = getMarketStatus(market, currentBlock);
  const bettingOpen = isMarketBettingOpen(market, currentBlock);
  const blocksLeft = market.deadline - currentBlock;
  const daysLeft = Math.max(0, Math.floor(blocksLeft / 144));
  const hoursLeft = Math.max(0, Math.floor((blocksLeft % 144) / 6));
  const yesPool = outcomes[0]?.pool || 0;
  const yesPercent = getOutcomePercentage(yesPool, market.totalPool);
  const noPercent = 100 - yesPercent;

  return (
    <Link href={`/market/${market.id}`} style={{ textDecoration: 'none' }}>
      <div className="card" style={{ cursor: 'pointer' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '16px' }}>
          <div style={{ fontSize: '10px', fontWeight: '700', letterSpacing: '0.1em', color: 'var(--text-muted)', textTransform: 'uppercase' }}>MARKET #{market.id}</div>
          <StatusBadge status={status} />
        </div>
        <h3 style={{ fontFamily: 'var(--font-display)', fontSize: '18px', fontWeight: '700', marginBottom: '16px', lineHeight: '1.3' }}>{market.title}</h3>
        {market.outcomeCount === 2 && (
          <div style={{ marginBottom: '16px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px', fontSize: '12px' }}>
              <span style={{ color: 'var(--accent-green)', fontWeight: '700' }}>{outcomes[0]?.label || 'YES'} {yesPercent}%</span>
              <span style={{ color: 'var(--accent-red)', fontWeight: '700' }}>{noPercent}% {outcomes[1]?.label || 'NO'}</span>
            </div>
            <div className="progress-bar">
              <div className="progress-fill progress-yes" style={{ width: `${yesPercent}%` }} />
            </div>
          </div>
        )}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '12px', paddingTop: '16px', borderTop: '1px solid var(--border-subtle)' }}>
          <div>
            <div style={{ fontSize: '10px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: '2px' }}>Pool</div>
            <div style={{ fontSize: '14px', fontWeight: '700', color: 'var(--accent-gold)' }}>{formatSTX(market.totalPool)}</div>
          </div>
          <div>
            <div style={{ fontSize: '10px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: '2px' }}>{market.resolved ? 'Winner' : 'Time Left'}</div>
            <div style={{ fontSize: '14px', fontWeight: '700', color: market.resolved ? 'var(--accent-green)' : 'var(--text-primary)' }}>
              {market.resolved ? (outcomes[market.winningOutcome]?.label || 'Resolved') : (blocksLeft > 0 ? `${daysLeft}d ${hoursLeft}h` : 'Ended')}
            </div>
          </div>
          <div style={{ textAlign: 'right' }}>
            {bettingOpen && <span style={{ fontSize: '11px', fontWeight: '700', color: 'var(--accent-electric)', textTransform: 'uppercase' }}>Bet Now →</span>}
          </div>
        </div>
      </div>
    </Link>
  );
}
