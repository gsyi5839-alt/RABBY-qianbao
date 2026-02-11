import { useState } from 'react';
import { useWallet } from '../contexts/WalletContext';

/* ---------- Types ---------- */

interface ActivityItem {
  id: string;
  type: 'signature' | 'transaction';
  title: string;
  description: string;
  status: 'pending' | 'expired';
  timestamp: number;
  dapp?: string;
  chain?: string;
  amount?: string;
}

/* ---------- Mock data ---------- */

const MOCK_ACTIVITIES: ActivityItem[] = [
  {
    id: '1',
    type: 'signature',
    title: 'Sign Message',
    description: 'Permit2 token approval for USDC on Uniswap',
    status: 'pending',
    timestamp: Date.now() - 120_000,
    dapp: 'Uniswap',
    chain: 'Ethereum',
  },
  {
    id: '2',
    type: 'transaction',
    title: 'Swap Tokens',
    description: 'Swap 1.5 ETH for 2,847.32 USDC',
    status: 'pending',
    timestamp: Date.now() - 300_000,
    dapp: 'Uniswap',
    chain: 'Ethereum',
    amount: '1.5 ETH',
  },
  {
    id: '3',
    type: 'signature',
    title: 'Sign Typed Data',
    description: 'NFT listing on OpenSea - Bored Ape #4291',
    status: 'pending',
    timestamp: Date.now() - 600_000,
    dapp: 'OpenSea',
    chain: 'Ethereum',
  },
  {
    id: '4',
    type: 'transaction',
    title: 'Bridge Assets',
    description: 'Bridge 500 USDC from Ethereum to Arbitrum',
    status: 'expired',
    timestamp: Date.now() - 3_600_000,
    dapp: 'Stargate',
    chain: 'Ethereum',
    amount: '500 USDC',
  },
  {
    id: '5',
    type: 'transaction',
    title: 'Approve Token',
    description: 'Approve DAI spending for Aave V3',
    status: 'expired',
    timestamp: Date.now() - 7_200_000,
    dapp: 'Aave',
    chain: 'Ethereum',
  },
];

/* ---------- SVG Icons ---------- */

function SignatureIcon() {
  return (
    <svg width="22" height="22" viewBox="0 0 22 22" fill="none">
      <path d="M3 17.5l3.5-1 10-10a1.5 1.5 0 0 0-2-2l-10 10L3 17.5z" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.6" fill="none" />
      <path d="M13 6l2 2" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.6" strokeLinecap="round" />
    </svg>
  );
}

function TransactionIcon() {
  return (
    <svg width="22" height="22" viewBox="0 0 22 22" fill="none">
      <path d="M4 8h14M14 4l4 4-4 4" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" fill="none" />
      <path d="M18 14H4M8 18l-4-4 4-4" stroke="var(--r-blue-default, #4c65ff)" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" fill="none" />
    </svg>
  );
}

function EmptyIcon() {
  return (
    <svg width="64" height="64" viewBox="0 0 64 64" fill="none">
      <circle cx="32" cy="32" r="28" stroke="var(--r-neutral-bg-2, #f2f4f7)" strokeWidth="3" fill="none" />
      <path d="M24 28h16M24 34h10" stroke="var(--r-neutral-foot, #6a7587)" strokeWidth="2" strokeLinecap="round" opacity="0.4" />
    </svg>
  );
}

/* ---------- Helpers ---------- */

function formatRelativeTime(ts: number): string {
  const diff = Date.now() - ts;
  const minutes = Math.floor(diff / 60_000);
  if (minutes < 1) return 'Just now';
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

/* ---------- Styles ---------- */

const pageContainer: React.CSSProperties = {
  minHeight: '100vh',
  background: 'var(--r-neutral-bg-2, #f2f4f7)',
  padding: '40px 24px',
  fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
};

const innerContainer: React.CSSProperties = {
  maxWidth: 720,
  margin: '0 auto',
};

const titleStyle: React.CSSProperties = {
  fontSize: 28,
  fontWeight: 700,
  color: 'var(--r-neutral-title-1, #192945)',
  margin: 0,
};

const subtitleStyle: React.CSSProperties = {
  fontSize: 15,
  color: 'var(--r-neutral-foot, #6a7587)',
  margin: '8px 0 0',
};

const filterRow: React.CSSProperties = {
  display: 'flex',
  gap: 8,
  marginTop: 24,
  marginBottom: 20,
};

const itemCard: React.CSSProperties = {
  background: 'var(--r-neutral-card-1, #fff)',
  borderRadius: 16,
  padding: '20px 24px',
  marginBottom: 12,
  display: 'flex',
  alignItems: 'flex-start',
  gap: 16,
  boxShadow: '0 1px 4px rgba(0,0,0,0.04)',
};

const iconBox: React.CSSProperties = {
  width: 44,
  height: 44,
  borderRadius: 12,
  background: 'var(--r-neutral-bg-2, #f2f4f7)',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  flexShrink: 0,
};

const statusBadge = (status: 'pending' | 'expired'): React.CSSProperties => ({
  display: 'inline-block',
  padding: '3px 10px',
  borderRadius: 20,
  fontSize: 12,
  fontWeight: 600,
  background: status === 'pending' ? 'rgba(76,101,255,0.08)' : 'rgba(106,117,135,0.08)',
  color: status === 'pending' ? 'var(--r-blue-default, #4c65ff)' : 'var(--r-neutral-foot, #6a7587)',
});

const approveBtn: React.CSSProperties = {
  padding: '8px 20px',
  borderRadius: 8,
  border: 'none',
  background: 'var(--r-blue-default, #4c65ff)',
  color: '#fff',
  fontSize: 13,
  fontWeight: 600,
  cursor: 'pointer',
  transition: 'opacity 0.2s',
};

const rejectBtn: React.CSSProperties = {
  padding: '8px 20px',
  borderRadius: 8,
  border: '1.5px solid #e5e7eb',
  background: 'transparent',
  color: 'var(--r-neutral-foot, #6a7587)',
  fontSize: 13,
  fontWeight: 600,
  cursor: 'pointer',
  transition: 'opacity 0.2s',
};

const emptyState: React.CSSProperties = {
  display: 'flex',
  flexDirection: 'column' as const,
  alignItems: 'center',
  justifyContent: 'center',
  padding: '80px 24px',
  background: 'var(--r-neutral-card-1, #fff)',
  borderRadius: 16,
  textAlign: 'center' as const,
};

const notConnectedCard: React.CSSProperties = {
  background: 'var(--r-neutral-card-1, #fff)',
  borderRadius: 16,
  padding: '60px 24px',
  textAlign: 'center' as const,
};

/* ---------- Filter Chip ---------- */

function FilterChip({
  label,
  active,
  count,
  onClick,
}: {
  label: string;
  active: boolean;
  count?: number;
  onClick: () => void;
}) {
  const chipStyle: React.CSSProperties = {
    padding: '7px 16px',
    borderRadius: 20,
    border: 'none',
    fontSize: 13,
    fontWeight: 600,
    cursor: 'pointer',
    background: active ? 'var(--r-blue-default, #4c65ff)' : 'var(--r-neutral-card-1, #fff)',
    color: active ? '#fff' : 'var(--r-neutral-foot, #6a7587)',
    transition: 'all 0.2s',
    display: 'flex',
    alignItems: 'center',
    gap: 6,
  };

  return (
    <button style={chipStyle} onClick={onClick}>
      {label}
      {count !== undefined && count > 0 && (
        <span
          style={{
            background: active ? 'rgba(255,255,255,0.25)' : 'var(--r-neutral-bg-2, #f2f4f7)',
            borderRadius: 10,
            padding: '1px 7px',
            fontSize: 11,
          }}
        >
          {count}
        </span>
      )}
    </button>
  );
}

/* ---------- Activity Item ---------- */

function ActivityCard({
  item,
  onApprove,
  onReject,
}: {
  item: ActivityItem;
  onApprove: (id: string) => void;
  onReject: (id: string) => void;
}) {
  return (
    <div style={itemCard}>
      <div style={iconBox}>
        {item.type === 'signature' ? <SignatureIcon /> : <TransactionIcon />}
      </div>

      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: 12,
            marginBottom: 4,
          }}
        >
          <span
            style={{
              fontSize: 15,
              fontWeight: 600,
              color: 'var(--r-neutral-title-1, #192945)',
            }}
          >
            {item.title}
          </span>
          <span style={statusBadge(item.status)}>
            {item.status === 'pending' ? 'Pending' : 'Expired'}
          </span>
        </div>

        <div
          style={{
            fontSize: 13,
            color: 'var(--r-neutral-foot, #6a7587)',
            lineHeight: 1.5,
            marginBottom: 8,
          }}
        >
          {item.description}
        </div>

        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 12,
            fontSize: 12,
            color: 'var(--r-neutral-foot, #6a7587)',
            marginBottom: item.status === 'pending' ? 14 : 0,
          }}
        >
          {item.dapp && (
            <span
              style={{
                background: 'var(--r-neutral-bg-2, #f2f4f7)',
                padding: '2px 8px',
                borderRadius: 4,
                fontWeight: 500,
              }}
            >
              {item.dapp}
            </span>
          )}
          {item.chain && <span>{item.chain}</span>}
          {item.amount && (
            <span style={{ fontWeight: 500 }}>{item.amount}</span>
          )}
          <span>{formatRelativeTime(item.timestamp)}</span>
        </div>

        {item.status === 'pending' && (
          <div style={{ display: 'flex', gap: 8 }}>
            <button
              style={approveBtn}
              onClick={() => onApprove(item.id)}
              onMouseEnter={(e) => (e.currentTarget.style.opacity = '0.85')}
              onMouseLeave={(e) => (e.currentTarget.style.opacity = '1')}
            >
              Approve
            </button>
            <button
              style={rejectBtn}
              onClick={() => onReject(item.id)}
              onMouseEnter={(e) => (e.currentTarget.style.opacity = '0.85')}
              onMouseLeave={(e) => (e.currentTarget.style.opacity = '1')}
            >
              Reject
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

/* ---------- Main Page ---------- */

type FilterType = 'all' | 'pending' | 'expired';

export default function Activities() {
  const { connected } = useWallet();
  const [filter, setFilter] = useState<FilterType>('all');
  const [activities, setActivities] = useState<ActivityItem[]>(MOCK_ACTIVITIES);

  const handleApprove = (id: string) => {
    console.log(`Approved activity: ${id}`);
    setActivities((prev) => prev.filter((a) => a.id !== id));
  };

  const handleReject = (id: string) => {
    console.log(`Rejected activity: ${id}`);
    setActivities((prev) => prev.filter((a) => a.id !== id));
  };

  const filtered =
    filter === 'all'
      ? activities
      : activities.filter((a) => a.status === filter);

  const pendingCount = activities.filter((a) => a.status === 'pending').length;
  const expiredCount = activities.filter((a) => a.status === 'expired').length;

  if (!connected) {
    return (
      <div style={pageContainer}>
        <div style={innerContainer}>
          <div style={notConnectedCard}>
            <h2
              style={{
                fontSize: 20,
                fontWeight: 600,
                color: 'var(--r-neutral-title-1, #192945)',
                margin: '0 0 8px',
              }}
            >
              Wallet Not Connected
            </h2>
            <p style={{ fontSize: 14, color: 'var(--r-neutral-foot, #6a7587)', margin: 0 }}>
              Please connect your wallet to view pending activities.
            </p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div style={pageContainer}>
      <div style={innerContainer}>
        <h1 style={titleStyle}>Activities</h1>
        <p style={subtitleStyle}>
          Pending signature requests and transactions that need your attention
        </p>

        <div style={filterRow}>
          <FilterChip
            label="All"
            active={filter === 'all'}
            count={activities.length}
            onClick={() => setFilter('all')}
          />
          <FilterChip
            label="Pending"
            active={filter === 'pending'}
            count={pendingCount}
            onClick={() => setFilter('pending')}
          />
          <FilterChip
            label="Expired"
            active={filter === 'expired'}
            count={expiredCount}
            onClick={() => setFilter('expired')}
          />
        </div>

        {filtered.length === 0 ? (
          <div style={emptyState}>
            <EmptyIcon />
            <h3
              style={{
                fontSize: 18,
                fontWeight: 600,
                color: 'var(--r-neutral-title-1, #192945)',
                margin: '20px 0 6px',
              }}
            >
              No Activities
            </h3>
            <p
              style={{
                fontSize: 14,
                color: 'var(--r-neutral-foot, #6a7587)',
                margin: 0,
              }}
            >
              {filter === 'all'
                ? 'You have no pending activities right now. Check back later.'
                : `No ${filter} activities at the moment.`}
            </p>
          </div>
        ) : (
          <div>
            {filtered.map((item) => (
              <ActivityCard
                key={item.id}
                item={item}
                onApprove={handleApprove}
                onReject={handleReject}
              />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
