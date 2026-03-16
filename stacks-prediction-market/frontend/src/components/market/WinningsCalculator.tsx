import { useState } from 'react';
import { formatSTX, stxToMicroSTX, microSTXtoSTX, CONTRACT_CONSTANTS } from '../../utils/contracts';

interface WinningsCalculatorProps {
  outcomePool: number;
  totalPool: number;
  outcomeName: string;
}

export function WinningsCalculator({ outcomePool, totalPool, outcomeName }: WinningsCalculatorProps) {
  const [betAmountSTX, setBetAmountSTX] = useState('');
  const betMicro = stxToMicroSTX(parseFloat(betAmountSTX) || 0);

  const newOutcomePool = outcomePool + betMicro;
  const newTotalPool = totalPool + betMicro;
  const platformFee = Math.floor(newTotalPool * CONTRACT_CONSTANTS.PLATFORM_FEE_BPS / CONTRACT_CONSTANTS.BPS_DENOMINATOR);
  const distributable = newTotalPool - platformFee;
  const estimatedPayout = newOutcomePool > 0 ? Math.floor((betMicro / newOutcomePool) * distributable) : 0;
  const profit = estimatedPayout - betMicro;
  const multiplier = betMicro > 0 && newOutcomePool > 0 ? (distributable / newOutcomePool).toFixed(2) : '0.00';

  return (
    <div style={{ background: 'var(--bg-secondary)', border: '1px solid var(--border-subtle)', borderRadius: 'var(--radius-md)', padding: '16px' }}>
      <div style={{ fontSize: '11px', fontWeight: '700', textTransform: 'uppercase', letterSpacing: '0.08em', color: 'var(--text-muted)', marginBottom: '12px' }}>
        💰 Winnings Calculator — {outcomeName}
      </div>
      <div style={{ marginBottom: '12px' }}>
        <label className="label">If I bet...</label>
        <input type="number" className="input" placeholder="0.0 STX" value={betAmountSTX} onChange={e => setBetAmountSTX(e.target.value)} min="0" step="1" />
      </div>
      {betMicro > 0 && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '13px' }}>
          {[
            { label: 'Estimated payout', value: formatSTX(estimatedPayout), color: 'var(--accent-green)' },
            { label: 'Estimated profit', value: `+${formatSTX(profit)}`, color: profit > 0 ? 'var(--accent-green)' : 'var(--accent-red)' },
            { label: 'Multiplier', value: `${multiplier}x`, color: 'var(--accent-electric)' },
            { label: 'Platform fee (2%)', value: formatSTX(platformFee), color: 'var(--text-muted)' },
          ].map(({ label, value, color }) => (
            <div key={label} style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ color: 'var(--text-muted)' }}>{label}</span>
              <span style={{ fontWeight: '700', color }}>{value}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
