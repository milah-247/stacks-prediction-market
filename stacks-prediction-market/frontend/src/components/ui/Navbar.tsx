import Link from 'next/link';
import { useRouter } from 'next/router';
import { WalletButton } from '../wallet/WalletButton';
import { useCurrentBlock } from '../../hooks/useMarkets';

export function Navbar() {
  const router = useRouter();
  const currentBlock = useCurrentBlock();
  const navLinks = [{ href: '/', label: 'Markets' }, { href: '/create', label: 'Create' }, { href: '/dashboard', label: 'Dashboard' }];
  return (
    <header style={{ position: 'sticky', top: 0, zIndex: 100, background: 'rgba(6, 7, 15, 0.9)', backdropFilter: 'blur(20px)', borderBottom: '1px solid var(--border-subtle)' }}>
      <div className="container" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', height: '64px' }}>
        <Link href="/" style={{ textDecoration: 'none' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div style={{ width: '32px', height: '32px', background: 'var(--accent-electric)', borderRadius: '8px', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '16px' }}>⬡</div>
            <div>
              <div style={{ fontFamily: 'var(--font-display)', fontWeight: '800', fontSize: '15px', color: 'var(--text-primary)' }}>StacksPM</div>
              <div style={{ fontSize: '9px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.1em' }}>Prediction Market</div>
            </div>
          </div>
        </Link>
        <nav style={{ display: 'flex', gap: '4px' }}>
          {navLinks.map(({ href, label }) => {
            const isActive = router.pathname === href;
            return (
              <Link key={href} href={href} style={{ textDecoration: 'none', padding: '6px 14px', borderRadius: 'var(--radius-sm)', fontSize: '12px', fontWeight: '700', textTransform: 'uppercase', letterSpacing: '0.08em', color: isActive ? 'var(--accent-electric)' : 'var(--text-secondary)', background: isActive ? 'rgba(91, 140, 247, 0.1)' : 'transparent', border: isActive ? '1px solid rgba(91, 140, 247, 0.2)' : '1px solid transparent', transition: 'all 0.2s ease' }}>
                {label}
              </Link>
            );
          })}
        </nav>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          {currentBlock > 0 && <div style={{ fontSize: '10px', color: 'var(--text-muted)', fontFamily: 'var(--font-mono)' }}>Block #{currentBlock.toLocaleString()}</div>}
          <WalletButton />
        </div>
      </div>
    </header>
  );
}
