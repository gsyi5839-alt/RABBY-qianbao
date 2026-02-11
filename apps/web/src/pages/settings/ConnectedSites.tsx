import { useState, useCallback } from 'react';
import { useWallet } from '../../contexts/WalletContext';

interface ConnectedSite {
  id: string;
  name: string;
  url: string;
  icon?: string;
  chain: string;
  connectedAt: number;
}

const MOCK_SITES: ConnectedSite[] = [
  {
    id: '1',
    name: 'Uniswap',
    url: 'https://app.uniswap.org',
    chain: 'Ethereum',
    connectedAt: Date.now() - 3600000,
  },
  {
    id: '2',
    name: 'OpenSea',
    url: 'https://opensea.io',
    chain: 'Ethereum',
    connectedAt: Date.now() - 86400000,
  },
  {
    id: '3',
    name: 'PancakeSwap',
    url: 'https://pancakeswap.finance',
    chain: 'BSC',
    connectedAt: Date.now() - 172800000,
  },
  {
    id: '4',
    name: 'Aave',
    url: 'https://app.aave.com',
    chain: 'Ethereum',
    connectedAt: Date.now() - 259200000,
  },
  {
    id: '5',
    name: 'GMX',
    url: 'https://app.gmx.io',
    chain: 'Arbitrum',
    connectedAt: Date.now() - 345600000,
  },
];

function getFaviconLetter(name: string): string {
  return name.charAt(0).toUpperCase();
}

function getFaviconColor(name: string): string {
  const colors = [
    '#ff007a', '#2081e2', '#d1884f', '#b6509e',
    '#3861fb', '#627eea', '#2b6def', '#e84142',
  ];
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = name.charCodeAt(i) + ((hash << 5) - hash);
  }
  return colors[Math.abs(hash) % colors.length];
}

function formatTimeAgo(timestamp: number): string {
  const diff = Date.now() - timestamp;
  const hours = Math.floor(diff / 3600000);
  if (hours < 1) return 'Just now';
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days === 1) return '1 day ago';
  return `${days} days ago`;
}

export default function ConnectedSites() {
  const { connected } = useWallet();
  const [sites, setSites] = useState<ConnectedSite[]>(connected ? MOCK_SITES : []);

  const handleDisconnect = useCallback((id: string) => {
    setSites((prev) => prev.filter((s) => s.id !== id));
  }, []);

  const handleDisconnectAll = useCallback(() => {
    setSites([]);
  }, []);

  const isEmpty = !connected || sites.length === 0;

  return (
    <div style={{ maxWidth: 780, margin: '0 auto', padding: '0 20px' }}>
      {/* Header */}
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: 24,
        }}
      >
        <div>
          <h2
            style={{
              margin: 0,
              fontSize: 24,
              fontWeight: 600,
              color: 'var(--r-neutral-title-1, #192945)',
            }}
          >
            Connected Sites
          </h2>
          <p
            style={{
              margin: '6px 0 0',
              fontSize: 14,
              color: 'var(--r-neutral-foot, #6a7587)',
            }}
          >
            {sites.length > 0
              ? `${sites.length} site${sites.length !== 1 ? 's' : ''} connected`
              : 'Manage your DApp connections'}
          </p>
        </div>
        {sites.length > 0 && (
          <button
            onClick={handleDisconnectAll}
            style={{
              padding: '10px 20px',
              background: 'rgba(236,81,81,0.08)',
              color: '#ec5151',
              border: 'none',
              borderRadius: 8,
              fontSize: 13,
              fontWeight: 500,
              cursor: 'pointer',
              transition: 'background 0.15s',
            }}
            onMouseEnter={(e) => {
              (e.currentTarget as HTMLElement).style.background = 'rgba(236,81,81,0.15)';
            }}
            onMouseLeave={(e) => {
              (e.currentTarget as HTMLElement).style.background = 'rgba(236,81,81,0.08)';
            }}
          >
            Disconnect All
          </button>
        )}
      </div>

      {/* Empty state */}
      {isEmpty ? (
        <div
          style={{
            background: 'var(--r-neutral-card-1, #fff)',
            borderRadius: 16,
            padding: '60px 20px',
            textAlign: 'center',
          }}
        >
          <div
            style={{
              width: 72,
              height: 72,
              borderRadius: '50%',
              background: 'var(--r-neutral-card-2, #f2f4f7)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              margin: '0 auto 20px',
            }}
          >
            {/* Globe/link icon */}
            <svg
              width="32"
              height="32"
              viewBox="0 0 32 32"
              fill="none"
              style={{ color: 'var(--r-neutral-foot, #6a7587)' }}
            >
              <circle
                cx="16"
                cy="16"
                r="12"
                stroke="currentColor"
                strokeWidth="1.5"
              />
              <path
                d="M4 16h24M16 4c3.314 4 5 8 5 12s-1.686 8-5 12c-3.314-4-5-8-5-12s1.686-8 5-12Z"
                stroke="currentColor"
                strokeWidth="1.5"
              />
            </svg>
          </div>
          <p
            style={{
              fontSize: 16,
              fontWeight: 500,
              color: 'var(--r-neutral-title-1, #192945)',
              margin: '0 0 8px',
            }}
          >
            No Connected Sites
          </p>
          <p
            style={{
              fontSize: 14,
              color: 'var(--r-neutral-foot, #6a7587)',
              margin: 0,
              maxWidth: 320,
              marginLeft: 'auto',
              marginRight: 'auto',
              lineHeight: 1.5,
            }}
          >
            {!connected
              ? 'Connect your wallet first, then visit DApps to establish connections.'
              : 'Visit a DApp and connect to it. Your connected sites will appear here.'}
          </p>
        </div>
      ) : (
        /* Sites list */
        <div
          style={{
            background: 'var(--r-neutral-card-1, #fff)',
            borderRadius: 16,
            overflow: 'hidden',
          }}
        >
          {sites.map((site, index) => (
            <div
              key={site.id}
              style={{
                display: 'flex',
                alignItems: 'center',
                padding: '16px 20px',
                gap: 14,
                borderBottom:
                  index < sites.length - 1
                    ? '1px solid var(--r-neutral-line, #e5e9ef)'
                    : 'none',
                transition: 'background 0.15s',
              }}
              onMouseEnter={(e) => {
                (e.currentTarget as HTMLElement).style.background =
                  'var(--r-neutral-card-2, #f7f8fa)';
              }}
              onMouseLeave={(e) => {
                (e.currentTarget as HTMLElement).style.background = 'transparent';
              }}
            >
              {/* Favicon placeholder */}
              <div
                style={{
                  width: 40,
                  height: 40,
                  borderRadius: 10,
                  background: getFaviconColor(site.name),
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: 18,
                  fontWeight: 700,
                  color: '#fff',
                  flexShrink: 0,
                }}
              >
                {getFaviconLetter(site.name)}
              </div>

              {/* Site info */}
              <div style={{ flex: 1, minWidth: 0 }}>
                <div
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 8,
                    marginBottom: 4,
                  }}
                >
                  <span
                    style={{
                      fontSize: 15,
                      fontWeight: 500,
                      color: 'var(--r-neutral-title-1, #192945)',
                    }}
                  >
                    {site.name}
                  </span>
                  {/* Chain badge */}
                  <span
                    style={{
                      fontSize: 11,
                      fontWeight: 500,
                      color: 'var(--r-blue-default, #4c65ff)',
                      background: 'var(--r-blue-light-1, rgba(76,101,255,0.08))',
                      padding: '2px 8px',
                      borderRadius: 4,
                    }}
                  >
                    {site.chain}
                  </span>
                </div>
                <div
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 8,
                  }}
                >
                  <span
                    style={{
                      fontSize: 13,
                      color: 'var(--r-neutral-foot, #6a7587)',
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                      whiteSpace: 'nowrap',
                    }}
                  >
                    {site.url}
                  </span>
                  <span
                    style={{
                      fontSize: 12,
                      color: 'var(--r-neutral-foot, #6a7587)',
                      opacity: 0.6,
                      whiteSpace: 'nowrap',
                    }}
                  >
                    {formatTimeAgo(site.connectedAt)}
                  </span>
                </div>
              </div>

              {/* Disconnect button */}
              <button
                onClick={() => handleDisconnect(site.id)}
                style={{
                  padding: '8px 16px',
                  background: 'transparent',
                  border: '1px solid var(--r-neutral-line, #e5e9ef)',
                  borderRadius: 8,
                  fontSize: 13,
                  color: 'var(--r-neutral-foot, #6a7587)',
                  cursor: 'pointer',
                  whiteSpace: 'nowrap',
                  transition: 'all 0.15s',
                  flexShrink: 0,
                }}
                onMouseEnter={(e) => {
                  const el = e.currentTarget as HTMLElement;
                  el.style.borderColor = '#ec5151';
                  el.style.color = '#ec5151';
                  el.style.background = 'rgba(236,81,81,0.04)';
                }}
                onMouseLeave={(e) => {
                  const el = e.currentTarget as HTMLElement;
                  el.style.borderColor = 'var(--r-neutral-line, #e5e9ef)';
                  el.style.color = 'var(--r-neutral-foot, #6a7587)';
                  el.style.background = 'transparent';
                }}
              >
                Disconnect
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
