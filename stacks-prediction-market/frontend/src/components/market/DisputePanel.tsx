import { useState } from 'react';
import { openContractCall } from '@stacks/connect';
import { Cl } from '@stacks/transactions';
import { CONTRACTS } from '../../utils/constants';
import { getNetwork } from '../../utils/contracts';
import { AnchorMode, PostConditionMode, stringUtf8CV, uintCV } from '@stacks/transactions';

interface DisputePanelProps {
  marketId: number;
  resolutionBlock: number;
  currentBlock: number;
  onSuccess?: () => void;
}

export function DisputePanel({ marketId, resolutionBlock, currentBlock, onSuccess }: DisputePanelProps) {
  const [reason, setReason] = useState('');
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');

  const disputeWindowEnd = resolutionBlock + 144;
  const blocksLeft = disputeWindowEnd - currentBlock;

  if (blocksLeft <= 0) return null;

  async function handleDispute() {
    if (!reason.trim()) return;
    setLoading(true);
    try {
      await openContractCall({
        contractAddress: CONTRACTS.predictionMarket.address,
        contractName: CONTRACTS.predictionMarket.name,
        functionName: 'dispute-market',
        functionArgs: [uintCV(marketId), stringUtf8CV(reason)],
        network: getNetwork(),
        anchorMode: AnchorMode.Any,
        postConditionMode: PostConditionMode.Allow,
        onFinish: (data: any) => {
          setMessage(`Dispute submitted! TX: ${data.txId.slice(0, 12)}...`);
          onSuccess?.();
        },
        onCancel: () => setLoading(false),
      });
    } catch { setMessage('Dispute failed.'); } finally { setLoading(false); }
  }

  return (
    <div className="card" style={{ borderColor: 'rgba(240,85,114,0.3)', marginTop: '16px' }}>
      <div style={{ fontFamily: 'var(--font-display)', fontWeight: '700', fontSize: '16px', color: 'var(--accent-red)', marginBottom: '8px' }}>
        ⚠ Dispute Resolution
      </div>
      <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '16px' }}>
        Dispute window closes in {blocksLeft} blocks. Only dispute if the resolution was incorrect.
      </div>
      <div style={{ marginBottom: '12px' }}>
        <label className="label">Reason for dispute</label>
        <textarea className="input" rows={3} placeholder="Explain why the resolution is incorrect..." value={reason} onChange={e => setReason(e.target.value)} maxLength={256} />
      </div>
      <button className="btn btn-danger w-full" onClick={handleDispute} disabled={loading || !reason.trim()}>
        {loading ? 'Submitting...' : 'Submit Dispute'}
      </button>
      {message && <div style={{ marginTop: '12px', fontSize: '12px', color: 'var(--accent-red)' }}>{message}</div>}
    </div>
  );
}
