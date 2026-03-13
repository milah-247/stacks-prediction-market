import { useState } from 'react';
import Head from 'next/head';
import { useRouter } from 'next/router';
import { openContractCall } from '@stacks/connect';
import { useWalletStore } from '../hooks/useWallet';
import { buildCreateMarketTx, estimateDeadlineBlock } from '../utils/contracts';
import { useCurrentBlock } from '../hooks/useMarkets';

export default function CreateMarketPage() {
  const router = useRouter();
  const { connected } = useWalletStore();
  const currentBlock = useCurrentBlock();
  const [step, setStep] = useState(1);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [outcomeA, setOutcomeA] = useState('YES');
  const [outcomeB, setOutcomeB] = useState('NO');
  const [daysUntilDeadline, setDaysUntilDeadline] = useState(7);
  const [loading, setLoading] = useState(false);
  const [txMessage, setTxMessage] = useState('');
  const deadlineBlock = estimateDeadlineBlock(currentBlock, daysUntilDeadline);
  const steps = [{ num: 1, label: 'Market Info' }, { num: 2, label: 'Outcomes' }, { num: 3, label: 'Timeline' }, { num: 4, label: 'Review' }];

  if (!connected) return (
    <div className="container" style={{ padding: '80px 24px', textAlign: 'center' }}>
      <div style={{ fontSize: '48px', marginBottom: '16px' }}>⬡</div>
      <div style={{ fontFamily: 'var(--font-display)', fontSize: '28px', marginBottom: '12px' }}>Connect Your Wallet</div>
      <div style={{ color: 'var(--text-secondary)' }}>You need a Stacks wallet to create prediction markets.</div>
    </div>
  );

  async function handleSubmit() {
    setLoading(true);
    try {
      await openContractCall({
        ...buildCreateMarketTx({ title: title.trim(), description: description.trim(), outcomeA: outcomeA.trim(), outcomeB: outcomeB.trim(), deadline: deadlineBlock }),
        onFinish: (data: any) => { setTxMessage(`Market created! TX: ${data.txId}`); setTimeout(() => router.push('/'), 2000); },
        onCancel: () => setLoading(false),
      });
    } catch { setTxMessage('Transaction failed.'); } finally { setLoading(false); }
  }

  return (
    <>
      <Head><title>Create Market — Stacks Prediction Market</title></Head>
      <div className="container" style={{ padding: '48px 24px' }}>
        <div style={{ maxWidth: '640px', margin: '0 auto' }}>
          <div style={{ marginBottom: '40px' }}>
            <div style={{ fontSize: '11px', color: 'var(--accent-electric)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '8px' }}>New Prediction Market</div>
            <h1 style={{ fontFamily: 'var(--font-display)', fontWeight: '800', fontSize: '36px', letterSpacing: '-0.02em' }}>Create a Market</h1>
          </div>

          <div style={{ display: 'flex', gap: '0', marginBottom: '40px', position: 'relative' }}>
            <div style={{ position: 'absolute', top: '14px', left: '14px', right: '14px', height: '2px', background: 'var(--border-subtle)', zIndex: 0 }} />
            {steps.map(({ num, label }) => {
              const isActive = step === num; const isDone = step > num;
              return (
                <div key={num} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', position: 'relative', zIndex: 1 }}>
                  <div style={{ width: '28px', height: '28px', borderRadius: '50%', background: isDone ? 'var(--accent-green)' : isActive ? 'var(--accent-electric)' : 'var(--bg-card)', border: `2px solid ${isDone ? 'var(--accent-green)' : isActive ? 'var(--accent-electric)' : 'var(--border-subtle)'}`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '11px', fontWeight: '700', color: isDone || isActive ? '#fff' : 'var(--text-muted)' }}>
                    {isDone ? '✓' : num}
                  </div>
                  <div style={{ fontSize: '10px', marginTop: '6px', color: isActive ? 'var(--accent-electric)' : 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.06em', fontWeight: isActive ? '700' : '400' }}>{label}</div>
                </div>
              );
            })}
          </div>

          {step === 1 && (
            <div className="animate-slide-in card">
              <div style={{ fontFamily: 'var(--font-display)', fontWeight: '700', fontSize: '18px', marginBottom: '24px' }}>What are you predicting?</div>
              <div style={{ marginBottom: '20px' }}>
                <label className="label">Market Title *</label>
                <input className="input" type="text" placeholder="e.g. Will BTC reach $150k before Dec 31?" value={title} onChange={e => setTitle(e.target.value)} maxLength={200} />
                <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '4px', textAlign: 'right' }}>{title.length}/200</div>
              </div>
              <div style={{ marginBottom: '20px' }}>
                <label className="label">Description (optional)</label>
                <textarea className="input" placeholder="Provide resolution criteria..." value={description} onChange={e => setDescription(e.target.value)} maxLength={800} rows={4} />
              </div>
              <button className="btn btn-primary w-full" onClick={() => setStep(2)} disabled={title.trim().length === 0}>Continue →</button>
            </div>
          )}

          {step === 2 && (
            <div className="animate-slide-in card">
              <div style={{ fontFamily: 'var(--font-display)', fontWeight: '700', fontSize: '18px', marginBottom: '24px' }}>Define the outcomes</div>
              <div style={{ marginBottom: '16px' }}>
                <label className="label">Outcome A *</label>
                <input className="input" value={outcomeA} onChange={e => setOutcomeA(e.target.value)} placeholder="YES" maxLength={50} />
              </div>
              <div style={{ marginBottom: '20px' }}>
                <label className="label">Outcome B *</label>
                <input className="input" value={outcomeB} onChange={e => setOutcomeB(e.target.value)} placeholder="NO" maxLength={50} />
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <button className="btn btn-secondary w-full" onClick={() => setStep(1)}>← Back</button>
                <button className="btn btn-primary w-full" onClick={() => setStep(3)} disabled={!outcomeA.trim() || !outcomeB.trim()}>Continue →</button>
              </div>
            </div>
          )}

          {step === 3 && (
            <div className="animate-slide-in card">
              <div style={{ fontFamily: 'var(--font-display)', fontWeight: '700', fontSize: '18px', marginBottom: '24px' }}>Set the deadline</div>
              <div style={{ marginBottom: '24px' }}>
                <label className="label">Days until market closes</label>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '8px', marginBottom: '16px' }}>
                  {[1, 3, 7, 14, 30, 60, 90, 180].map(d => (
                    <button key={d} onClick={() => setDaysUntilDeadline(d)} style={{ padding: '10px', border: `2px solid ${daysUntilDeadline === d ? 'var(--accent-electric)' : 'var(--border-subtle)'}`, borderRadius: 'var(--radius-sm)', background: daysUntilDeadline === d ? 'rgba(91,140,247,0.1)' : 'var(--bg-secondary)', color: daysUntilDeadline === d ? 'var(--accent-electric)' : 'var(--text-secondary)', cursor: 'pointer', fontSize: '12px', fontWeight: '700', fontFamily: 'var(--font-mono)' }}>{d}d</button>
                  ))}
                </div>
                <div style={{ background: 'var(--bg-secondary)', border: '1px solid var(--border-subtle)', borderRadius: 'var(--radius-md)', padding: '16px', fontSize: '13px', color: 'var(--text-secondary)' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}><span>Current block:</span><span style={{ color: 'var(--text-primary)', fontWeight: '700' }}>#{currentBlock.toLocaleString()}</span></div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}><span>Deadline block:</span><span style={{ color: 'var(--accent-electric)', fontWeight: '700' }}>#{deadlineBlock.toLocaleString()}</span></div>
                </div>
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <button className="btn btn-secondary w-full" onClick={() => setStep(2)}>← Back</button>
                <button className="btn btn-primary w-full" onClick={() => setStep(4)}>Review →</button>
              </div>
            </div>
          )}

          {step === 4 && (
            <div className="animate-slide-in card">
              <div style={{ fontFamily: 'var(--font-display)', fontWeight: '700', fontSize: '18px', marginBottom: '24px' }}>Review & Deploy</div>
              <div style={{ background: 'var(--bg-secondary)', borderRadius: 'var(--radius-md)', padding: '20px', marginBottom: '24px' }}>
                <div style={{ marginBottom: '12px' }}><div style={{ fontSize: '10px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '4px' }}>Title</div><div style={{ fontFamily: 'var(--font-display)', fontWeight: '700' }}>{title}</div></div>
                <div style={{ marginBottom: '12px' }}><div style={{ fontSize: '10px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '8px' }}>Outcomes</div><div style={{ display: 'flex', gap: '8px' }}>{[outcomeA, outcomeB].map((o, i) => <span key={i} style={{ padding: '4px 12px', background: 'var(--bg-card)', border: '1px solid var(--border-subtle)', borderRadius: '100px', fontSize: '13px', fontWeight: '700' }}>{o}</span>)}</div></div>
                <div><div style={{ fontSize: '10px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '4px' }}>Deadline</div><div style={{ fontSize: '14px' }}>Block <span style={{ color: 'var(--accent-electric)', fontWeight: '700' }}>#{deadlineBlock.toLocaleString()}</span> (~{daysUntilDeadline} days)</div></div>
              </div>
              {txMessage && <div style={{ background: 'rgba(91, 140, 247, 0.1)', border: '1px solid var(--accent-electric)', borderRadius: 'var(--radius-md)', padding: '12px 16px', fontSize: '13px', color: 'var(--accent-electric)', marginBottom: '16px', wordBreak: 'break-all' }}>{txMessage}</div>}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <button className="btn btn-secondary w-full" onClick={() => setStep(3)}>← Back</button>
                <button className="btn btn-primary w-full btn-lg" onClick={handleSubmit} disabled={loading}>{loading ? 'Deploying...' : '⬡ Deploy Market'}</button>
              </div>
            </div>
          )}
        </div>
      </div>
    </>
  );
}
