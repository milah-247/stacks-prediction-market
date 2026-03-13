import { useCallback, useEffect } from 'react';
import { showConnect, UserSession, AppConfig } from '@stacks/connect';
import { useWalletStore } from '../../hooks/useWallet';
import { APP_CONFIG, CURRENT_NETWORK } from '../../utils/constants';

const appConfig = new AppConfig(['store_write', 'publish_data']);
export const userSession = new UserSession({ appConfig });

export function WalletButton() {
  const { connected, address, connect, disconnect } = useWalletStore();

  useEffect(() => {
    if (userSession.isUserSignedIn()) {
      const data = userSession.loadUserData();
      const addr = CURRENT_NETWORK === 'mainnet' ? data.profile.stxAddress.mainnet : data.profile.stxAddress.testnet;
      connect(addr, data.profile.stxAddress.mainnet, data.profile.stxAddress.testnet);
    }
  }, [connect]);

  const handleConnect = useCallback(() => {
    showConnect({
      appDetails: { name: APP_CONFIG.name, icon: APP_CONFIG.appIconUrl },
      userSession,
      onFinish: () => {
        const data = userSession.loadUserData();
        const addr = CURRENT_NETWORK === 'mainnet' ? data.profile.stxAddress.mainnet : data.profile.stxAddress.testnet;
        connect(addr, data.profile.stxAddress.mainnet, data.profile.stxAddress.testnet);
      },
    });
  }, [connect]);

  const handleDisconnect = useCallback(() => { userSession.signUserOut(); disconnect(); }, [disconnect]);

  if (connected && address) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
        <div style={{ background: 'var(--bg-secondary)', border: '1px solid var(--border-subtle)', borderRadius: 'var(--radius-sm)', padding: '8px 14px', fontSize: '12px', color: 'var(--text-secondary)' }}>
          <span style={{ color: 'var(--accent-green)', marginRight: '6px' }}>●</span>
          {address.slice(0, 6)}...{address.slice(-4)}
        </div>
        <button className="btn btn-secondary btn-sm" onClick={handleDisconnect}>Disconnect</button>
      </div>
    );
  }
  return <button className="btn btn-primary" onClick={handleConnect}><span>⬡</span> Connect Wallet</button>;
}
