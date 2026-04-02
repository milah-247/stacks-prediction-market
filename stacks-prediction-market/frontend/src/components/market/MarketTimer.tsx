import { useCurrentBlock } from '../../hooks/useMarkets';
import { type Market, CONTRACT_CONSTANTS } from '../../utils/contracts';

interface MarketTimerProps { market: Market; }

// Fix: clamp negative countdown values to zero to prevent display overflow
export function MarketTimer({ market }: MarketTimerProps) {
  const currentBlock = useCurrentBlock();
  // Clamp to 0 so negative values never reach the display layer
  const blocksLeft = Math.max(0, market.deadline - currentBlock);
  const cutoffBlock = market.deadline - CONTRACT_CONSTANTS.BETTING_CUTOFF_BLOCKS;
  const bettingOpen = currentBlock < cutoffBlock;
  const daysLeft = Math.floor(blocksLeft / 144);
  const hoursLeft = Math.floor((blocksLeft % 144) / 6);
  const blocksUntilCutoff = cutoffBlock - currentBlock;

  if (market.resolved) return (
    <div style={{ fontSize: '12px', color: 'var(--accent-green)', fontWeight: '700' }}>
      ✓ Market Resolved at block #{market.resolutionBlock.toLocaleString()}
    </div>
  );

  if (blocksLeft <= 0) return (
    <div style={{ fontSize: '12px', color: 'var(--accent-gold)', fontWeight: '700' }}>
      ⏳ Deadline passed — awaiting resolution
    </div>
  );

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
      <div style={{ display: 'flex', gap: '8px' }}>
        {[
          { label: 'Days', value: daysLeft },
          { label: 'Hours', value: hoursLeft },
          { label: 'Blocks', value: blocksLeft.toLocaleString() },
        ].map(({ label, value }) => (
          <div key={label} style={{
            background: 'var(--bg-secondary)', border: '1px solid var(--border-subtle)',
            borderRadius: 'var(--radius-sm)', padding: '8px 12px', textAlign: 'center', flex: 1,
          }}>
            <div style={{ fontFamily: 'var(--font-display)', fontWeight: '800', fontSize: '20px', color: 'var(--text-primary)' }}>{value}</div>
            <div style={{ fontSize: '10px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em' }}>{label}</div>
          </div>
        ))}
      </div>
      {bettingOpen && blocksUntilCutoff < 288 && (
        <div style={{ fontSize: '11px', color: 'var(--accent-gold)', textAlign: 'center' }}>
          ⚠ Betting closes in {blocksUntilCutoff} blocks (~{Math.floor(blocksUntilCutoff / 6)}h)
        </div>
      )}
    </div>
  );
}
