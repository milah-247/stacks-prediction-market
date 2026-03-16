import { type Market, formatSTX, CONTRACT_CONSTANTS } from '../../utils/contracts';

interface PoolStatsProps { market: Market; }

export function PoolStats({ market }: PoolStatsProps) {
  const platformFee = Math.floor(market.totalPool * CONTRACT_CONSTANTS.PLATFORM_FEE_BPS / CONTRACT_CONSTANTS.BPS_DENOMINATOR);
  const distributablePool = market.totalPool - platformFee;

  const stats = [
    { label: 'Total Pool',      value: formatSTX(market.totalPool),     color: 'var(--accent-gold)' },
    { label: 'Distributable',   value: formatSTX(distributablePool),    color: 'var(--accent-green)' },
    { label: 'Platform Fee',    value: formatSTX(platformFee),          color: 'var(--text-muted)' },
    { label: 'Deadline Block',  value: `#${market.deadline.toLocaleString()}`, color: 'var(--text-primary)' },
  ];

  return (
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
      {stats.map(({ label, value, color }) => (
        <div key={label} style={{
          background: 'var(--bg-secondary)', border: '1px solid var(--border-subtle)',
          borderRadius: 'var(--radius-md)', padding: '16px',
        }}>
          <div style={{ fontSize: '10px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: '6px' }}>
            {label}
          </div>
          <div style={{ fontFamily: 'var(--font-display)', fontWeight: '700', fontSize: '18px', color }}>
            {value}
          </div>
        </div>
      ))}
    </div>
  );
}
