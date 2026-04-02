import { useState, useEffect } from 'react';
import Navbar from '../components/ui/Navbar';

interface LeaderboardEntry {
  rank: number;
  address: string;
  totalWinnings: number;
  marketsWon: number;
  winRate: number;
}

const MOCK_DATA: LeaderboardEntry[] = [
  { rank: 1, address: 'SP1ABC...XYZ1', totalWinnings: 450000000, marketsWon: 18, winRate: 72 },
  { rank: 2, address: 'SP2DEF...XYZ2', totalWinnings: 320000000, marketsWon: 14, winRate: 65 },
  { rank: 3, address: 'SP3GHI...XYZ3', totalWinnings: 210000000, marketsWon: 11, winRate: 58 },
  { rank: 4, address: 'SP4JKL...XYZ4', totalWinnings: 180000000, marketsWon: 9, winRate: 53 },
  { rank: 5, address: 'SP5MNO...XYZ5', totalWinnings: 95000000, marketsWon: 6, winRate: 46 },
];

function formatSTX(microSTX: number) {
  return (microSTX / 1_000_000).toFixed(2) + ' STX';
}

export default function Leaderboard() {
  const [entries, setEntries] = useState<LeaderboardEntry[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Replace with real on-chain query
    setTimeout(() => { setEntries(MOCK_DATA); setLoading(false); }, 500);
  }, []);

  return (
    <div className="min-h-screen bg-gray-950 text-white">
      <Navbar />
      <main className="max-w-4xl mx-auto px-4 py-10">
        <h1 className="text-3xl font-bold mb-2">Leaderboard</h1>
        <p className="text-gray-400 mb-8">Top predictors ranked by total winnings</p>

        {loading ? (
          <p className="text-gray-500">Loading...</p>
        ) : (
          <div className="overflow-x-auto rounded-xl border border-gray-800">
            <table className="w-full text-sm">
              <thead className="bg-gray-900 text-gray-400 uppercase text-xs">
                <tr>
                  {['Rank', 'Address', 'Total Winnings', 'Markets Won', 'Win Rate'].map(h => (
                    <th key={h} className="px-4 py-3 text-left">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {entries.map((e) => (
                  <tr key={e.rank} className="border-t border-gray-800 hover:bg-gray-900 transition-colors">
                    <td className="px-4 py-3 font-bold text-yellow-400">#{e.rank}</td>
                    <td className="px-4 py-3 font-mono text-blue-400">{e.address}</td>
                    <td className="px-4 py-3 text-green-400">{formatSTX(e.totalWinnings)}</td>
                    <td className="px-4 py-3">{e.marketsWon}</td>
                    <td className="px-4 py-3">{e.winRate}%</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </main>
    </div>
  );
}
