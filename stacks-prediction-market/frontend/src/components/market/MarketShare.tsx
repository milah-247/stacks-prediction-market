import { useState } from 'react';
import { type Market } from '../../utils/contracts';

interface MarketShareProps { market: Market; }

export function MarketShare({ market }: MarketShareProps) {
  const [copied, setCopied] = useState(false);

  const shareUrl = typeof window !== 'undefined'
    ? `${window.location.origin}/market/${market.id}`
    : `/market/${market.id}`;

  const shareText = `🔮 "${market.title}" — Predict the outcome on Stacks Prediction Market!`;

  function handleCopy() {
    navigator.clipboard.writeText(shareUrl);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }

  function handleTwitter() {
    const url = `https://twitter.com/intent/tweet?text=${encodeURIComponent(shareText)}&url=${encodeURIComponent(shareUrl)}`;
    window.open(url, '_blank');
  }

  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
      <button onClick={handleCopy} className="btn btn-secondary btn-sm">
        {copied ? '✓ Copied!' : '🔗 Copy Link'}
      </button>
      <button onClick={handleTwitter} className="btn btn-secondary btn-sm">
        𝕏 Share
      </button>
    </div>
  );
}
