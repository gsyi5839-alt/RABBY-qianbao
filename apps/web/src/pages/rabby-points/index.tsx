import { useState } from 'react';
import { useWallet } from '../../contexts/WalletContext';

interface Activity {
  id: string;
  title: string;
  description: string;
  points: number;
  completed: boolean;
  type: 'daily' | 'volume' | 'referral' | 'social';
}

interface LeaderboardEntry {
  rank: number;
  address: string;
  points: number;
}

const MOCK_ACTIVITIES: Activity[] = [
  { id: '1', title: 'Daily Check-in', description: 'Visit Rabby every day', points: 50, completed: false, type: 'daily' },
  { id: '2', title: 'Swap Volume', description: 'Complete $1,000+ in swaps this week', points: 200, completed: false, type: 'volume' },
  { id: '3', title: 'Referral Bonus', description: 'Invite a friend to use Rabby', points: 500, completed: true, type: 'referral' },
  { id: '4', title: 'Social Share', description: 'Share your Rabby stats on Twitter', points: 100, completed: false, type: 'social' },
  { id: '5', title: 'Bridge Activity', description: 'Complete 3 cross-chain bridges', points: 150, completed: true, type: 'volume' },
];

const MOCK_LEADERBOARD: LeaderboardEntry[] = [
  { rank: 1, address: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1', points: 48250 },
  { rank: 2, address: '0xaabbccddee11223344556677889900aabbccddee', points: 42100 },
  { rank: 3, address: '0x1234567890abcdef1234567890abcdef12345678', points: 38900 },
  { rank: 4, address: '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef', points: 35600 },
  { rank: 5, address: '0x9876543210fedcba9876543210fedcba98765432', points: 31200 },
];

const USER_POINTS = 12580;
const USER_RANK = 127;

function truncAddr(addr: string) {
  return addr.slice(0, 6) + '...' + addr.slice(-4);
}

export default function RabbyPointsPage() {
  const { connected } = useWallet();
  const [activities, setActivities] = useState(MOCK_ACTIVITIES);
  const [claiming, setClaiming] = useState<string | null>(null);

  const handleClaim = async (id: string) => {
    setClaiming(id);
    await new Promise((r) => setTimeout(r, 1200));
    setActivities((prev) =>
      prev.map((a) => (a.id === id ? { ...a, completed: true } : a))
    );
    setClaiming(null);
  };

  if (!connected) {
    return (
      <div style={{ padding: 24, maxWidth: 600, margin: '0 auto' }}>
        <h2 style={{
          fontSize: 24,
          fontWeight: 600,
          color: 'var(--r-neutral-title-1, #192945)',
          marginBottom: 16,
        }}>
          Rabby Points
        </h2>
        <div style={{
          background: 'var(--r-neutral-card-1, #fff)',
          borderRadius: 16,
          padding: 40,
          textAlign: 'center',
        }}>
          <p style={{ color: 'var(--r-neutral-foot, #6a7587)', fontSize: 14 }}>
            Please connect your wallet to view your points.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div style={{ padding: 24, maxWidth: 600, margin: '0 auto' }}>
      <h2 style={{
        fontSize: 24,
        fontWeight: 600,
        color: 'var(--r-neutral-title-1, #192945)',
        marginBottom: 24,
      }}>
        Rabby Points
      </h2>

      {/* Points Balance Card with Gradient */}
      <div style={{
        background: 'linear-gradient(135deg, var(--r-blue-default, #4c65ff) 0%, #7084ff 50%, #a78bfa 100%)',
        borderRadius: 16,
        padding: 32,
        marginBottom: 16,
        color: '#fff',
        position: 'relative',
        overflow: 'hidden',
      }}>
        <div style={{
          position: 'absolute',
          top: -40,
          right: -40,
          width: 160,
          height: 160,
          borderRadius: '50%',
          background: 'rgba(255,255,255,0.08)',
        }} />
        <div style={{
          position: 'absolute',
          bottom: -20,
          left: -20,
          width: 100,
          height: 100,
          borderRadius: '50%',
          background: 'rgba(255,255,255,0.06)',
        }} />
        <div style={{ fontSize: 14, opacity: 0.85, marginBottom: 8 }}>
          Your Points Balance
        </div>
        <div style={{ fontSize: 40, fontWeight: 700, marginBottom: 8 }}>
          {USER_POINTS.toLocaleString()}
        </div>
        <div style={{
          display: 'flex',
          alignItems: 'center',
          gap: 16,
          fontSize: 13,
          opacity: 0.85,
        }}>
          <span>Rank #{USER_RANK}</span>
          <span style={{
            width: 1,
            height: 14,
            background: 'rgba(255,255,255,0.3)',
            display: 'inline-block',
          }} />
          <span>Top 2.5%</span>
        </div>
        <div style={{
          display: 'flex',
          gap: 12,
          marginTop: 24,
        }}>
          <button style={{
            padding: '10px 28px',
            borderRadius: 8,
            border: 'none',
            background: '#fff',
            color: 'var(--r-blue-default, #4c65ff)',
            fontSize: 14,
            fontWeight: 600,
            cursor: 'pointer',
          }}>
            Redeem
          </button>
          <button style={{
            padding: '10px 28px',
            borderRadius: 8,
            border: '1px solid rgba(255,255,255,0.5)',
            background: 'transparent',
            color: '#fff',
            fontSize: 14,
            fontWeight: 600,
            cursor: 'pointer',
          }}>
            History
          </button>
        </div>
      </div>

      {/* Activities / Tasks */}
      <div style={{
        background: 'var(--r-neutral-card-1, #fff)',
        borderRadius: 16,
        padding: 20,
        marginBottom: 16,
      }}>
        <div style={{
          fontSize: 16,
          fontWeight: 600,
          color: 'var(--r-neutral-title-1, #192945)',
          marginBottom: 16,
        }}>
          Earn Points
        </div>
        {activities.map((activity) => (
          <div
            key={activity.id}
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              padding: '14px 16px',
              borderRadius: 12,
              background: 'var(--r-neutral-card-2, #f2f4f7)',
              marginBottom: 8,
            }}
          >
            <div style={{ flex: 1, minWidth: 0, marginRight: 12 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{
                  fontSize: 14,
                  fontWeight: 500,
                  color: 'var(--r-neutral-title-1, #192945)',
                }}>
                  {activity.title}
                </span>
                <span style={{
                  fontSize: 12,
                  fontWeight: 600,
                  color: 'var(--r-blue-default, #4c65ff)',
                }}>
                  +{activity.points}
                </span>
              </div>
              <div style={{
                fontSize: 12,
                color: 'var(--r-neutral-foot, #6a7587)',
                marginTop: 3,
              }}>
                {activity.description}
              </div>
            </div>
            {activity.completed ? (
              <span style={{
                fontSize: 12,
                fontWeight: 500,
                color: 'var(--r-green-default, #27c193)',
                padding: '6px 16px',
                borderRadius: 6,
                background: 'rgba(39,193,147,0.1)',
                flexShrink: 0,
              }}>
                Claimed
              </span>
            ) : (
              <button
                onClick={() => handleClaim(activity.id)}
                disabled={claiming === activity.id}
                style={{
                  padding: '6px 16px',
                  borderRadius: 6,
                  border: 'none',
                  background: 'var(--r-blue-default, #4c65ff)',
                  color: '#fff',
                  fontSize: 12,
                  fontWeight: 600,
                  cursor: claiming === activity.id ? 'not-allowed' : 'pointer',
                  opacity: claiming === activity.id ? 0.6 : 1,
                  flexShrink: 0,
                  transition: 'opacity 0.2s',
                }}
              >
                {claiming === activity.id ? 'Claiming...' : 'Claim'}
              </button>
            )}
          </div>
        ))}
      </div>

      {/* Leaderboard */}
      <div style={{
        background: 'var(--r-neutral-card-1, #fff)',
        borderRadius: 16,
        padding: 20,
      }}>
        <div style={{
          fontSize: 16,
          fontWeight: 600,
          color: 'var(--r-neutral-title-1, #192945)',
          marginBottom: 16,
        }}>
          Leaderboard
        </div>
        {MOCK_LEADERBOARD.map((entry) => (
          <div
            key={entry.rank}
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              padding: '12px 16px',
              borderRadius: 12,
              background: entry.rank <= 3
                ? 'rgba(76,101,255,0.04)'
                : 'var(--r-neutral-card-2, #f2f4f7)',
              marginBottom: 8,
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
              <div style={{
                width: 28,
                height: 28,
                borderRadius: '50%',
                background: entry.rank === 1
                  ? '#FFD700'
                  : entry.rank === 2
                    ? '#C0C0C0'
                    : entry.rank === 3
                      ? '#CD7F32'
                      : 'var(--r-neutral-line, #e5e9ef)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: 12,
                fontWeight: 700,
                color: entry.rank <= 3 ? '#fff' : 'var(--r-neutral-foot, #6a7587)',
                flexShrink: 0,
              }}>
                {entry.rank}
              </div>
              <span style={{
                fontSize: 14,
                fontFamily: 'monospace',
                color: 'var(--r-neutral-title-1, #192945)',
              }}>
                {truncAddr(entry.address)}
              </span>
            </div>
            <span style={{
              fontSize: 14,
              fontWeight: 600,
              color: 'var(--r-neutral-title-1, #192945)',
            }}>
              {entry.points.toLocaleString()}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
