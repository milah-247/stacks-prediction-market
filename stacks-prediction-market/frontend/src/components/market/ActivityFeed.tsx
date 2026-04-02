import { useEffect, useState } from 'react';

interface ActivityEvent {
  id: string;
  type: 'bet' | 'resolve' | 'claim' | 'dispute';
  marketId: number;
  user: string;
  amount?: number;
  outcome?: string;
  timestamp: number;
}

const TYPE_LABELS: Record<ActivityEvent['type'], { label: string; color: string }> = {
  bet: { label: 'Bet Placed', color: 'text-blue-400' },
  resolve: { label: 'Resolved', color: 'text-green-400' },
  claim: { label: 'Claimed', color: 'text-yellow-400' },
  dispute: { label: 'Disputed', color: 'text-red-400' },
};

const MOCK_EVENTS: ActivityEvent[] = [
  { id: '1', type: 'bet', marketId: 3, user: 'SP1AB...', amount: 2_000_000, outcome: 'YES', timestamp: Date.now() - 30000 },
  { id: '2', type: 'resolve', marketId: 2, user: 'SP2CD...', timestamp: Date.now() - 120000 },
  { id: '3', type: 'claim', marketId: 1, user: 'SP3EF...', amount: 9_800_000, timestamp: Date.now() - 300000 },
  { id: '4', type: 'dispute', marketId: 4, user: 'SP4GH...', timestamp: Date.now() - 600000 },
];

function timeAgo(ts: number) {
  const s = Math.floor((Date.now() - ts) / 1000);
  if (s < 60) return `${s}s ago`;
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  return `${Math.floor(s / 3600)}h ago`;
}

interface Props { marketId?: number; limit?: number; }

export default function ActivityFeed({ marketId, limit = 10 }: Props) {
  const [events, setEvents] = useState<ActivityEvent[]>([]);

  useEffect(() => {
    const filtered = marketId ? MOCK_EVENTS.filter(e => e.marketId === marketId) : MOCK_EVENTS;
    setEvents(filtered.slice(0, limit));
  }, [marketId, limit]);

  if (events.length === 0) return <p className="text-gray-500 text-sm">No recent activity.</p>;

  return (
    <div className="space-y-2">
      {events.map((e) => {
        const { label, color } = TYPE_LABELS[e.type];
        return (
          <div key={e.id} className="flex items-center justify-between bg-gray-900 rounded-lg px-3 py-2 text-sm border border-gray-800">
            <div className="flex items-center gap-2">
              <span className={`font-semibold ${color}`}>{label}</span>
              <span className="text-gray-400">Market #{e.marketId}</span>
              {e.amount && <span className="text-white">{(e.amount / 1e6).toFixed(2)} STX</span>}
            </div>
            <span className="text-gray-500 text-xs">{timeAgo(e.timestamp)}</span>
          </div>
        );
      })}
    </div>
  );
}
