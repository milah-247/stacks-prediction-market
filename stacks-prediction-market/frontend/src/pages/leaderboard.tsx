import { useEffect, useState } from 'react';
import Navbar from '../components/ui/Navbar';

interface LeaderboardEntry {
  rank: number;
  address: string;
  totalWinnings: number;
  marketsWon: number;
  totalBets: number;
}

export default function Leaderboard() {
  const [entries, setEntries] = useState<LeaderboardEntry[]>([]);

  useEffect(() => {
    // Placeholder: fetch leaderboard data from indexer/API
    setEntries([
      { rank: 1, address: 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ', totalWinnings: 15000, marketsWon: 12, totalBets: 20 },
      { rank: 2, address: 'SP1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE', totalWinnings: 9800, marketsWon: 8, totalBets: 15 },
      { rank: 3, address: 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE', totalWinnings: 7200, marketsWon: 6, totalBets: 11 },
    ]);
  }, []);

  return (
    <div className="min-h-screen bg-gray-950 text-white">
      <Navbar />
      <main className="max-w-4xl mx-auto px-4 py-10">
        <h1 className="text-3xl font-bold mb-6">Leaderboard</h1>
        <table className="w-full text-sm border-collapse">
          <thead>
            <tr className="text-gray-400 border-b border-gray-700">
              <th className="py-2 text-left">Rank</th>
              <th className="py-2 text-left">Address</th>
              <th className="py-2 text-right">Markets Won</th>
              <th className="py-2 text-right">Total Bets</th>
              <th className="py-2 text-right">Total Winnings (STX)</th>
            </tr>
          </thead>
          <tbody>
            {entries.map((e) => (
              <tr key={e.rank} className="border-b border-gray-800 hover:bg-gray-900">
                <td className="py-3">{e.rank}</td>
                <td className="py-3 font-mono text-xs">{e.address.slice(0, 12)}…{e.address.slice(-6)}</td>
                <td className="py-3 text-right">{e.marketsWon}</td>
                <td className="py-3 text-right">{e.totalBets}</td>
                <td className="py-3 text-right text-green-400">{(e.totalWinnings / 1_000_000).toFixed(2)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </main>
    </div>
  );
}
