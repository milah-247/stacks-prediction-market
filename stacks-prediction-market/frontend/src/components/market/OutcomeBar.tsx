import { type MarketOutcome, formatSTX, getOutcomePercentage } from '../../utils/contracts';

interface OutcomeBarProps {
  outcomes: MarketOutcome[];
  totalPool: number;
  winningOutcome?: number;
  resolved?: boolean;
}

const OUTCOME_COLORS = [
  { bar: 'var(--accent-green)', bg: 'rgba(61,214,140,0.1)', border: 'rgba(61,214,140,0.3)' },
  { bar: 'var(--accent-red)',   bg: 'rgba(240,85,114,0.1)',  border: 'rgba(240,85,114,0.3)' },
  { bar: 'var(--accent-purple)',bg: 'rgba(168,85,247,0.1)',  border: 'rgba(168,85,247,0.3)' },
];

export function OutcomeBar({ outcomes, totalPool, winningOutcome, resolved }: OutcomeBarProps) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
      {outcomes.map((outcome, i) => {
        const pct = getOutcomePercentage(outcome.pool, totalPool);
        const color = OUTCOME_COLORS[i % OUTCOME_COLORS.length];
        const isWinner = resolved && winningOutcome === i;
        return (
          <div key={i} style={{
            background: isWinner ? color.bg : 'transparent',
            border: isWinner ? `1px solid ${color.border}` : '1px solid transparent',
            borderRadius: 'var(--radius-sm)', padding: isWinner ? '10px' : '0',
            transition: 'all 0.3s ease',
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px', fontSize: '13px' }}>
              <span style={{ fontWeight: '700', color: isWinner ? color.bar : 'var(--text-primary)' }}>
                {isWinner && '🏆 '}{outcome.label}
              </span>
              <div style={{ display: 'flex', gap: '12px' }}>
                <span style={{ color: 'var(--text-muted)' }}>{formatSTX(outcome.pool)}</span>
                <span style={{ fontWeight: '700', color: color.bar }}>{pct}%</span>
              </div>
            </div>
            <div style={{ height: '8px', background: 'var(--bg-secondary)', borderRadius: '100px', overflow: 'hidden' }}>
              <div style={{
                height: '100%', width: `${pct}%`,
                background: `linear-gradient(90deg, ${color.bar}, ${color.bar}88)`,
                borderRadius: '100px', transition: 'width 0.8s ease',
              }} />
            </div>
          </div>
        );
      })}
    </div>
  );
}
