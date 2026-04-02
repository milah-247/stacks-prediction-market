import { useEffect, useState } from 'react';
import Navbar from '../components/ui/Navbar';
import { useWallet } from '../hooks/useWallet';

interface Position {
  marketId: number;
  title: string;
  outcome: string;
  amount: number;
  status: 'active' | 'won' | 'lost' | 'pending';
  payout?: number;
}

const STATUS_COLORS: Record<Position['status'], string> = {
  active: 'text-blue-400 bg-blue-900/30',
  won: 'text-green-400 bg-green-900/30',
  lost: 'text-red-400 bg-red-900/30',
  pending: 'text-yellow-400 bg-yellow-900/30',
};

export default function Portfolio() {
  const { address } = useWallet();
  const [positions, setPositions] = useState<Position[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!address) { setLoading(false); return; }
    // Replace with real contract reads
    setPositions([
      { marketId: 1, title: 'Will BTC reach $100k?', outcome: 'YES', amount: 5_000_000, status: 'won', payout: 9_800_000 },
      { marketId: 2, title: 'ETH merge success?', outcome: 'YES', amount: 2_000_000, status: 'lost' },
      { marketId: 3, title: 'STX price above $3?', outcome: 'NO', amount: 1_000_000, status: 'active' },
    ]);
    setLoading(false);
  }, [address]);

  const totalStaked = positions.reduce((s, p) => s + p.amount, 0);
  const totalPayout = positions.reduce((s, p) => s + (p.payout ?? 0), 0);

  return (
    <div className="min-h-screen bg-gray-950 text-white">
      <Navbar />
      <main className="max-w-4xl mx-auto px-4 py-10">
        <h1 className="text-3xl font-bold mb-2">My Portfolio</h1>
        <p className="text-gray-400 mb-6">Track your active and past predictions</p>

        {!address ? (
          <p className="text-gray-500">Connect your wallet to view your portfolio.</p>
        ) : loading ? (
          <p className="text-gray-500">Loading positions...</p>
        ) : (
          <>
            <div className="grid grid-cols-2 gap-4 mb-8">
              <div className="bg-gray-900 rounded-xl p-4 border border-gray-800">
                <p className="text-gray-400 text-sm">Total Staked</p>
                <p className="text-2xl font-bold text-white">{(totalStaked / 1e6).toFixed(2)} STX</p>
              </div>
              <div className="bg-gray-900 rounded-xl p-4 border border-gray-800">
                <p className="text-gray-400 text-sm">Total Claimed</p>
                <p className="text-2xl font-bold text-green-400">{(totalPayout / 1e6).toFixed(2)} STX</p>
              </div>
            </div>

            <div className="space-y-3">
              {positions.map((p) => (
                <div key={p.marketId} className="bg-gray-900 rounded-xl p-4 border border-gray-800 flex items-center justify-between">
                  <div>
                    <p className="font-medium">{p.title}</p>
                    <p className="text-sm text-gray-400">Bet: <span className="text-white">{p.outcome}</span> · {(p.amount / 1e6).toFixed(2)} STX</p>
                  </div>
                  <span className={`text-xs font-semibold px-2 py-1 rounded-full ${STATUS_COLORS[p.status]}`}>
                    {p.status.toUpperCase()}
                  </span>
                </div>
              ))}
            </div>
          </>
        )}
      </main>
    </div>
  );
}
