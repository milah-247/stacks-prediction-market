import { useCallback, useEffect, useState } from 'react';
import { showConnect, UserSession, AppConfig } from '@stacks/connect';
import { useWalletStore } from '../../hooks/useWallet';
import { APP_CONFIG, CURRENT_NETWORK } from '../../utils/constants';

const appConfig = new AppConfig(['store_write', 'publish_data']);
export const userSession = new UserSession({ appConfig });

export function WalletButton() {
  const { connected, address, connect, disconnect } = useWalletStore();
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (userSession.isUserSignedIn()) {
      const data = userSession.loadUserData();
      const addr = CURRENT_NETWORK === 'mainnet'
        ? data.profile.stxAddress.mainnet
        : data.profile.stxAddress.testnet;
      connect(addr, data.profile.stxAddress.mainnet, data.profile.stxAddress.testnet);
    }
  }, [connect]);

  const handleConnect = useCallback(() => {
    showConnect({
      appDetails: { name: APP_CONFIG.name, icon: APP_CONFIG.appIconUrl },
      userSession,
      onFinish: () => {
        const data = userSession.loadUserData();
        const addr = CURRENT_NETWORK === 'mainnet'
          ? data.profile.stxAddress.mainnet
          : data.profile.stxAddress.testnet;
        connect(addr, data.profile.stxAddress.mainnet, data.profile.stxAddress.testnet);
      },
    });
  }, [connect]);

  // Signs out from Stacks wallet and clears local session state
  const handleDisconnect = useCallback(() => {
    userSession.signUserOut();
    disconnect();
  }, [disconnect]);

  // Copies full address to clipboard with visual feedback
  const handleCopyAddress = useCallback(() => {
    if (!address) return;
    navigator.clipboard.writeText(address);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }, [address]);

  if (connected && address) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
        <span style={{
          fontSize: '9px', fontWeight: '700', textTransform: 'uppercase',
          letterSpacing: '0.1em', padding: '2px 6px', borderRadius: '4px',
          background: CURRENT_NETWORK === 'mainnet'
            ? 'rgba(240,192,64,0.15)' : 'rgba(91,140,247,0.15)',
          color: CURRENT_NETWORK === 'mainnet'
            ? 'var(--accent-gold)' : 'var(--accent-electric)',
          border: CURRENT_NETWORK === 'mainnet'
            ? '1px solid rgba(240,192,64,0.3)' : '1px solid rgba(91,140,247,0.3)',
        }}>
          {CURRENT_NETWORK}
        </span>
        <div
          onClick={handleCopyAddress}
          title={copied ? 'Copied!' : 'Click to copy address'}
          style={{
            background: 'var(--bg-secondary)', border: '1px solid var(--border-subtle)',
            borderRadius: 'var(--radius-sm)', padding: '8px 14px', fontSize: '12px',
            color: copied ? 'var(--accent-green)' : 'var(--text-secondary)',
            cursor: 'pointer', transition: 'color 0.2s ease',
          }}>
          <span style={{ color: 'var(--accent-green)', marginRight: '6px' }}>●</span>
          {copied ? 'Copied!' : `${address.slice(0, 6)}...${address.slice(-4)}`}
        </div>
        <button className="btn btn-secondary btn-sm" onClick={handleDisconnect}>
          Disconnect
        </button>
      </div>
    );
  }

  return (
    <button className="btn btn-primary" onClick={handleConnect}>
      <span>⬡</span> Connect Wallet
    </button>
  );
}
