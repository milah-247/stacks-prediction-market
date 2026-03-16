import { type Market, type MarketOutcome, formatSTX } from '../../utils/contracts';

interface BetEntry {
  marketId: number;
  outcomeIndex: number;
  amount: number;
  claimed: boolean;
  withdrawn: boolean;
}

interface BetHistoryProps {
  bets: BetEntry[];
  markets: Market[];
  outcomesMap: Record<number, MarketOutcome[]>;
}

export function BetHistory({ bets, markets, outcomesMap }: BetHistoryProps) {
  if (bets.length === 0) return (
    <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-muted)' }}>
      <div style={{ fontSize: '32px', marginBottom: '8px' }}>📋</div>
      <div>No bets placed yet</div>
    </div>
  );

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
      {bets.map((bet, i) => {
        const market = markets.find(m => m.id === bet.marketId);
        const outcomes = outcomesMap[bet.marketId] || [];
        const outcome = outcomes[bet.outcomeIndex];
        const isWinner = market?.resolved && market.winningOutcome === bet.outcomeIndex;
        const isLoser = market?.resolved && market.winningOutcome !== bet.outcomeIndex;

        return (
          <div key={i} style={{
            display: 'grid', gridTemplateColumns: '1fr auto',
            alignItems: 'center', gap: '16px',
            background: isWinner ? 'rgba(61,214,140,0.05)' : 'var(--bg-secondary)',
            border: `1px solid ${isWinner ? 'rgba(61,214,140,0.3)' : 'var(--border-subtle)'}`,
            borderRadius: 'var(--radius-md)', padding: '14px 16px',
            opacity: isLoser ? 0.5 : 1,
          }}>
            <div>
              <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '4px' }}>
                Market #{bet.marketId}
              </div>
              <div style={{ fontWeight: '700', fontSize: '14px', marginBottom: '4px' }}>
                {market?.title || 'Unknown Market'}
              </div>
              <div style={{ fontSize: '12px', display: 'flex', gap: '8px', alignItems: 'center' }}>
                <span style={{ color: 'var(--text-secondary)' }}>
                  Bet on: <strong>{outcome?.label || `Outcome ${bet.outcomeIndex}`}</strong>
                </span>
                {isWinner && <span style={{ color: 'var(--accent-green)' }}>🏆 Winner</span>}
                {bet.claimed && <span style={{ color: 'var(--accent-electric)' }}>✓ Claimed</span>}
                {bet.withdrawn && <span style={{ color: 'var(--text-muted)' }}>↩ Withdrawn</span>}
              </div>
            </div>
            <div style={{ textAlign: 'right' }}>
              <div style={{
                fontFamily: 'var(--font-display)', fontWeight: '800',
                fontSize: '18px', color: isWinner ? 'var(--accent-green)' : 'var(--accent-gold)'
              }}>
                {formatSTX(bet.amount)}
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}
