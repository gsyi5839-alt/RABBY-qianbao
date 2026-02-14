import React, { useEffect, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';

const MOCK_TOKENS = [
  { id: '1', symbol: 'ETH', name: 'Ethereum', status: 'whitelist', updatedAt: '2024-01-15' },
  { id: '2', symbol: 'USDC', name: 'USD Coin', status: 'whitelist', updatedAt: '2024-01-14' },
  { id: '3', symbol: 'ABC', name: 'Unknown Token', status: 'blacklist', updatedAt: '2024-01-10' },
];

const thStyle: React.CSSProperties = {
  textAlign: 'left',
  padding: '12px 16px',
  borderBottom: '2px solid var(--r-neutral-line, #f0f0f0)',
  color: 'var(--r-neutral-foot, #6a7587)',
  fontWeight: 600,
  fontSize: 12,
  textTransform: 'uppercase',
  letterSpacing: '0.5px',
  background: 'var(--r-neutral-bg-3, #fafafa)',
};

const tdStyle: React.CSSProperties = {
  padding: '12px 16px',
  borderBottom: '1px solid var(--r-neutral-line, #f0f0f0)',
  color: 'var(--r-neutral-body, #3e495e)',
  fontSize: 13,
};

const statusStyle: Record<string, React.CSSProperties> = {
  whitelist: { background: 'var(--r-green-light, #f6ffed)', color: 'var(--r-green-default, #389e0d)', border: '1px solid #b7eb8f' },
  blacklist: { background: 'var(--r-red-light, #fff2f0)', color: 'var(--r-red-default, #cf1322)', border: '1px solid #ffccc7' },
};

type TokenTab = 'list' | 'blacklist' | 'prices';

export default function TokensPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const [activeTab, setActiveTab] = useState<TokenTab>('list');

  useEffect(() => {
    if (location.pathname.includes('/tokens/blacklist')) {
      setActiveTab('blacklist');
    } else if (location.pathname.includes('/tokens/prices')) {
      setActiveTab('prices');
    } else {
      setActiveTab('list');
    }
  }, [location.pathname]);

  const tabRoutes: Record<TokenTab, string> = {
    list: '/tokens/list',
    blacklist: '/tokens/blacklist',
    prices: '/tokens/prices',
  };

  const filteredTokens = MOCK_TOKENS.filter((token) => {
    if (activeTab === 'list') return token.status === 'whitelist';
    if (activeTab === 'blacklist') return token.status === 'blacklist';
    return true;
  });

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <h2 style={{ margin: 0, fontSize: 22, color: 'var(--r-neutral-title-1, #192945)' }}>Token Management</h2>
        <button style={{
          padding: '8px 20px', borderRadius: 8, border: 'none',
          background: 'var(--r-blue-default, #4c65ff)', color: '#fff', fontSize: 13, fontWeight: 600, cursor: 'pointer',
        }}>
          + Add Token
        </button>
      </div>

      <div style={{ display: 'flex', gap: 0, marginBottom: 20 }}>
        {([
          { key: 'list' as const, label: 'Whitelist' },
          { key: 'blacklist' as const, label: 'Blacklist' },
          { key: 'prices' as const, label: 'Price Sources' },
        ]).map((tab) => (
          <button
            key={tab.key}
            onClick={() => navigate(tabRoutes[tab.key])}
            style={{
              padding: '10px 24px', border: 'none', cursor: 'pointer', fontSize: 14, fontWeight: 500,
              background: activeTab === tab.key ? '#fff' : 'transparent',
              color: activeTab === tab.key ? '#4c65ff' : '#6a7587',
              borderBottom: activeTab === tab.key ? '2px solid #4c65ff' : '2px solid transparent',
              borderRadius: '8px 8px 0 0',
            }}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {activeTab === 'prices' ? (
        <div style={{
          background: '#fff',
          borderRadius: 12,
          padding: 24,
          boxShadow: 'var(--rabby-shadow-sm, 0 1px 3px rgba(0,0,0,0.06))',
          color: 'var(--r-neutral-foot, #6a7587)',
        }}>
          Configure token price sources and priority here.
        </div>
      ) : (
        <div style={{ background: '#fff', borderRadius: 12, overflow: 'hidden', boxShadow: 'var(--rabby-shadow-sm, 0 1px 3px rgba(0,0,0,0.06))' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
            <thead>
              <tr>
                <th style={thStyle}>Symbol</th>
                <th style={thStyle}>Name</th>
                <th style={thStyle}>Status</th>
                <th style={thStyle}>Updated</th>
              </tr>
            </thead>
            <tbody>
              {filteredTokens.map((token) => (
                <tr key={token.id}
                  onMouseEnter={(e) => (e.currentTarget.style.background = '#fafbfc')}
                  onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
                >
                  <td style={{ ...tdStyle, fontWeight: 600 }}>{token.symbol}</td>
                  <td style={tdStyle}>{token.name}</td>
                  <td style={tdStyle}>
                    <span style={{ padding: '3px 10px', borderRadius: 12, fontSize: 11, fontWeight: 600, ...statusStyle[token.status] }}>
                      {token.status}
                    </span>
                  </td>
                  <td style={{ ...tdStyle, fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)' }}>{token.updatedAt}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
