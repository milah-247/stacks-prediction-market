import type { AppProps } from 'next/app';
import { Navbar } from '../components/ui/Navbar';
import '../styles/globals.css';

export default function App({ Component, pageProps }: AppProps) {
  return (
    <>
      <Navbar />
      <main style={{ position: 'relative', zIndex: 1, minHeight: 'calc(100vh - 64px)' }}>
        <Component {...pageProps} />
      </main>
      <footer style={{ borderTop: '1px solid var(--border-subtle)', padding: '24px', textAlign: 'center', color: 'var(--text-muted)', fontSize: '11px', fontFamily: 'var(--font-mono)', letterSpacing: '0.05em' }}>
        STACKS PREDICTION MARKET — BUILT ON BITCOIN · OPEN SOURCE ·{' '}
        <a href="https://github.com/your-repo/stacks-prediction-market" target="_blank" rel="noopener noreferrer" style={{ color: 'var(--accent-electric)', textDecoration: 'none' }}>GITHUB</a>
      </footer>
    </>
  );
}
