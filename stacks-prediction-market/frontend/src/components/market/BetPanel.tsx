import { useState } from 'react';
import { openContractCall } from '@stacks/connect';
import { type Market, type MarketOutcome, buildPlaceBetTx, buildEarlyWithdrawTx, buildClaimWinningsTx, formatSTX, stxToMicroSTX, microSTXtoSTX, isMarketBettingOpen, getOutcomePercentage } from '../../utils/contracts';
import { useWalletStore } from '../../hooks/useWallet';
import { useUserBets, useClaimInfo, useCurrentBlock } from '../../hooks/useMarkets';

export function BetPanel({ market, outcomes, onSuccess }: { market: Market; outcomes: MarketOutcome[]; onSuccess?: () => void; }) {
  const { connected, address } = useWalletStore();
  const currentBlock = useCurrentBlock();
  const { bets, refetch: refetchBets } = useUserBets(market.id, address, market.outcomeCount);
  const { claimStatus, potentialWinnings } = useClaimInfo(market.id, address, market.resolved);
  const [selectedOutcome, setSelectedOutcome] = useState<number | null>(null);
  const [betAmountSTX, setBetAmountSTX] = useState('');
  const [loading, setLoading] = useState(false);
  const [txMessage, setTxMessage] = useState<string | null>(null);

  const bettingOpen = isMarketBettingOpen(market, currentBlock);
  const betAmountMicro = stxToMicroSTX(parseFloat(betAmountSTX) || 0);

  async function handlePlaceBet() {
    if (!connected || selectedOutcome === null || betAmountMicro === 0) return;
    setLoading(true);
    try {
      await openContractCall({
        ...buildPlaceBetTx({ marketId: market.id, outcomeIndex: selectedOutcome, amount: betAmountMicro, senderAddress: address! }),
        onFinish: (data: any) => { setTxMessage(`Bet placed! TX: ${data.txId.slice(0, 12)}...`); setBetAmountSTX(''); setSelectedOutcome(null); setTimeout(() => { refetchBets(); onSuccess?.(); }, 3000); },
        onCancel: () => setLoading(false),
      });
    } catch { setTxMessage('Transaction failed.'); } finally { setLoading(false); }
  }

  async function handleClaim() {
    setLoading(true);
    try {
      await openContractCall({ ...buildClaimWinningsTx(market.id), onFinish: (data: any) => { setTxMessage(`Claimed! TX: ${data.txId.slice(0, 12)}...`); refetchBets(); onSuccess?.(); }, onCancel: () => setLoading(false) });
    } catch { setTxMessage('Claim failed.'); } finally { setLoading(false); }
  }

  async function handleEarlyWithdraw(outcomeIndex: number) {
    setLoading(true);
    try {
      await openContractCall({ ...buildEarlyWithdrawTx(market.id, outcomeIndex), onFinish: (data: any) => { setTxMessage(`Withdrawn! TX: ${data.txId.slice(0, 12)}...`); refetchBets(); onSuccess?.(); }, onCancel: () => setLoading(false) });
    } catch { setTxMessage('Withdrawal failed.'); } finally { setLoading(false); }
  }

  if (!connected) return (
    <div className="card" style={{ textAlign: 'center', padding: '40px' }}>
      <div style={{ fontSize: '32px', marginBottom: '12px' }}>⬡</div>
      <div style={{ fontFamily: 'var(--font-display)', fontSize: '18px', marginBottom: '8px' }}>Connect your wallet</div>
      <div style={{ color: 'var(--text-muted)', fontSize: '13px' }}>Connect a Stacks wallet to place bets or claim winnings</div>
    </div>
  );

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
      {market.resolved && !market.disputed && (
        <div className="card" style={{ borderColor: 'rgba(61, 214, 140, 0.3)' }}>
          <div style={{ fontFamily: 'var(--font-display)', fontSize: '16px', fontWeight: '700', marginBottom: '16px' }}>🏆 Claim Winnings</div>
          {claimStatus?.claimed ? (
            <div style={{ color: 'var(--accent-green)', fontSize: '14px' }}>✓ Claimed {formatSTX(claimStatus.amount)}</div>
          ) : potentialWinnings > 0 ? (
            <>
              <div style={{ marginBottom: '16px' }}>
                <div style={{ fontSize: '11px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em' }}>Your Winnings</div>
                <div style={{ fontSize: '28px', fontWeight: '700', color: 'var(--accent-gold)', fontFamily: 'var(--font-display)' }}>{formatSTX(potentialWinnings)}</div>
              </div>
              <button className="btn btn-gold w-full btn-lg" onClick={handleClaim} disabled={loading}>{loading ? 'Processing...' : '⬡ Claim Winnings'}</button>
            </>
          ) : <div style={{ color: 'var(--text-muted)', fontSize: '14px' }}>No winnings to claim.</div>}
        </div>
      )}

      {bettingOpen && (
        <div className="card">
          <div style={{ fontFamily: 'var(--font-display)', fontSize: '16px', fontWeight: '700', marginBottom: '20px' }}>Place a Bet</div>
          <div style={{ marginBottom: '20px' }}>
            <div className="label">Choose Outcome</div>
            <div style={{ display: 'grid', gridTemplateColumns: `repeat(${outcomes.length}, 1fr)`, gap: '8px' }}>
              {outcomes.map((outcome, i) => {
                const pct = getOutcomePercentage(outcome.pool, market.totalPool);
                const isSelected = selectedOutcome === i;
                const colors = ['var(--accent-green)', 'var(--accent-red)', 'var(--accent-purple)'];
                const color = colors[i % colors.length];
                return (
                  <button key={i} onClick={() => setSelectedOutcome(i)} style={{ background: isSelected ? `rgba(${i === 0 ? '61,214,140' : '240,85,114'}, 0.15)` : 'var(--bg-secondary)', border: `2px solid ${isSelected ? color : 'var(--border-subtle)'}`, borderRadius: 'var(--radius-md)', padding: '14px', cursor: 'pointer', transition: 'all 0.2s ease', textAlign: 'center' }}>
                    <div style={{ fontFamily: 'var(--font-display)', fontWeight: '700', color: isSelected ? color : 'var(--text-primary)', fontSize: '15px' }}>{outcome.label}</div>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '4px' }}>{pct}% · {formatSTX(outcome.pool)}</div>
                  </button>
                );
              })}
            </div>
          </div>
          <div style={{ marginBottom: '16px' }}>
            <label className="label">Bet Amount (STX)</label>
            <div style={{ position: 'relative' }}>
              <input type="number" className="input" placeholder="0.0" value={betAmountSTX} onChange={e => setBetAmountSTX(e.target.value)} min="0" step="0.1" style={{ paddingRight: '60px' }} />
              <span style={{ position: 'absolute', right: '12px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)', fontSize: '12px', fontWeight: '700' }}>STX</span>
            </div>
          </div>
          <div style={{ display: 'flex', gap: '8px', marginBottom: '20px' }}>
            {[1, 5, 10, 25].map(amt => <button key={amt} className="btn btn-secondary btn-sm" onClick={() => setBetAmountSTX(String(amt))}>{amt} STX</button>)}
          </div>
          <button className="btn btn-primary w-full btn-lg" onClick={handlePlaceBet} disabled={loading || selectedOutcome === null || betAmountMicro === 0}>
            {loading ? 'Confirming...' : selectedOutcome !== null ? `Bet on ${outcomes[selectedOutcome]?.label}` : 'Select an outcome'}
          </button>
        </div>
      )}

      {bets.some(b => b && b.amount > 0) && (
        <div className="card">
          <div style={{ fontFamily: 'var(--font-display)', fontSize: '16px', fontWeight: '700', marginBottom: '16px' }}>Your Bets</div>
          {bets.map((bet, i) => {
            if (!bet || bet.amount === 0) return null;
            return (
              <div key={i} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '12px', background: 'var(--bg-secondary)', borderRadius: 'var(--radius-sm)', marginBottom: '8px' }}>
                <div>
                  <div style={{ fontWeight: '700', fontSize: '14px' }}>{outcomes[i]?.label || `Outcome ${i}`}</div>
                  <div style={{ color: 'var(--accent-gold)', fontSize: '13px' }}>
                    {formatSTX(bet.amount)}
                    {bet.claimed && <span style={{ color: 'var(--accent-green)', marginLeft: '8px' }}>✓ Claimed</span>}
                    {bet.withdrawn && <span style={{ color: 'var(--text-muted)', marginLeft: '8px' }}>Withdrawn</span>}
                  </div>
                </div>
                {!market.resolved && !bet.withdrawn && !bet.claimed && bettingOpen && (
                  <button className="btn btn-secondary btn-sm" onClick={() => handleEarlyWithdraw(i)} disabled={loading}>Withdraw (5% fee)</button>
                )}
              </div>
            );
          })}
        </div>
      )}

      {txMessage && (
        <div style={{ background: 'var(--bg-card)', border: '1px solid var(--accent-electric)', borderRadius: 'var(--radius-md)', padding: '12px 16px', fontSize: '13px', color: 'var(--accent-electric)' }}>
          {txMessage}
        </div>
      )}
    </div>
  );
}
