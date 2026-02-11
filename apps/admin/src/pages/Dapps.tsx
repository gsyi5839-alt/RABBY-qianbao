import React, { useState } from 'react';

const MOCK_DAPPS = [
  { id: '1', name: 'Uniswap', url: 'https://app.uniswap.org', icon: 'UNI', category: 'DEX', chain: 'Multi-chain', users: '45.2K', volume: '$12.5M', status: 'approved', enabled: true, order: 1, addedDate: '2023-06-15' },
  { id: '2', name: 'Aave', url: 'https://app.aave.com', icon: 'AAVE', category: 'Lending', chain: 'Multi-chain', users: '28.1K', volume: '$8.3M', status: 'approved', enabled: true, order: 2, addedDate: '2023-06-15' },
  { id: '3', name: 'OpenSea', url: 'https://opensea.io', icon: 'OS', category: 'NFT', chain: 'Ethereum', users: '67.8K', volume: '$5.1M', status: 'approved', enabled: true, order: 3, addedDate: '2023-07-01' },
  { id: '4', name: 'Lido', url: 'https://stake.lido.fi', icon: 'LDO', category: 'Staking', chain: 'Ethereum', users: '18.9K', volume: '$25.7M', status: 'approved', enabled: true, order: 4, addedDate: '2023-07-10' },
  { id: '5', name: 'Curve', url: 'https://curve.fi', icon: 'CRV', category: 'DEX', chain: 'Multi-chain', users: '12.3K', volume: '$3.8M', status: 'approved', enabled: true, order: 5, addedDate: '2023-08-01' },
  { id: '6', name: 'GMX', url: 'https://gmx.io', icon: 'GMX', category: 'Perps', chain: 'Arbitrum', users: '8.5K', volume: '$15.2M', status: 'approved', enabled: false, order: 6, addedDate: '2023-09-15' },
  { id: '7', name: 'Stargate', url: 'https://stargate.finance', icon: 'STG', category: 'Bridge', chain: 'Multi-chain', users: '5.2K', volume: '$2.1M', status: 'approved', enabled: true, order: 7, addedDate: '2023-10-01' },
];

const REVIEW_QUEUE = [
  { id: 'r1', name: 'NewDEX Protocol', url: 'https://newdex.xyz', category: 'DEX', chain: 'Arbitrum', submittedBy: 'community', submittedDate: '2024-01-14', status: 'pending_review' },
  { id: 'r2', name: 'YieldMax', url: 'https://yieldmax.fi', category: 'Lending', chain: 'Ethereum', submittedBy: 'partner', submittedDate: '2024-01-13', status: 'pending_review' },
  { id: 'r3', name: 'NFT Gallery Pro', url: 'https://nftgallery.pro', category: 'NFT', chain: 'Polygon', submittedBy: 'community', submittedDate: '2024-01-12', status: 'under_review' },
];

const CATEGORY_COLORS: Record<string, string> = {
  DEX: '#4c65ff', NFT: '#8b5cf6', Lending: '#2abb7f', Staking: '#ffb020',
  Perps: '#ff6b6b', Bridge: '#28A0F0', Other: '#6a7587',
};

const STATUS_STYLES: Record<string, React.CSSProperties> = {
  approved: { background: '#f6ffed', color: '#389e0d', border: '1px solid #b7eb8f' },
  pending_review: { background: '#fff7e6', color: '#d46b08', border: '1px solid #ffd591' },
  under_review: { background: '#e6f7ff', color: '#096dd9', border: '1px solid #91d5ff' },
  rejected: { background: '#fff2f0', color: '#cf1322', border: '1px solid #ffccc7' },
};

const thStyle: React.CSSProperties = {
  textAlign: 'left', padding: '12px 16px', borderBottom: '2px solid #f0f0f0',
  color: '#6a7587', fontWeight: 600, fontSize: 12, textTransform: 'uppercase',
  letterSpacing: '0.5px', background: '#fafafa',
};

const tdStyle: React.CSSProperties = {
  padding: '12px 16px', borderBottom: '1px solid #f0f0f0', color: '#3e495e', fontSize: 13,
};

export default function DappsPage() {
  const [activeTab, setActiveTab] = useState<'dapps' | 'review'>('dapps');
  const [search, setSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('all');

  const filteredDapps = MOCK_DAPPS.filter((d) => {
    const matchSearch = !search || d.name.toLowerCase().includes(search.toLowerCase())
      || d.url.toLowerCase().includes(search.toLowerCase());
    const matchCategory = categoryFilter === 'all' || d.category === categoryFilter;
    return matchSearch && matchCategory;
  });

  const filteredQueue = REVIEW_QUEUE.filter((r) =>
    !search || r.name.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <h2 style={{ margin: 0, fontSize: 22, color: '#192945' }}>DApp Management</h2>
        <div style={{ display: 'flex', gap: 8 }}>
          <button style={{
            padding: '8px 20px', borderRadius: 8, border: '1px solid #d9d9d9',
            background: '#fff', fontSize: 13, fontWeight: 500, cursor: 'pointer', color: '#3e495e',
          }}>
            Export
          </button>
          <button style={{
            padding: '8px 20px', borderRadius: 8, border: 'none',
            background: '#4c65ff', color: '#fff', fontSize: 13, fontWeight: 600, cursor: 'pointer',
          }}>
            + Add DApp
          </button>
        </div>
      </div>

      {/* Tabs */}
      <div style={{ display: 'flex', gap: 0, marginBottom: 20 }}>
        {([
          { key: 'dapps' as const, label: `All DApps (${MOCK_DAPPS.length})` },
          { key: 'review' as const, label: `Review Queue (${REVIEW_QUEUE.length})` },
        ]).map((tab) => (
          <button
            key={tab.key}
            onClick={() => { setActiveTab(tab.key); setSearch(''); setCategoryFilter('all'); }}
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

      {/* Filters */}
      <div style={{
        display: 'flex', gap: 12, marginBottom: 20, padding: 16,
        background: '#fff', borderRadius: 12, boxShadow: '0 1px 3px rgba(0,0,0,0.06)',
      }}>
        <input
          value={search} onChange={(e) => setSearch(e.target.value)}
          placeholder="Search DApps..."
          style={{ flex: 1, padding: '8px 14px', borderRadius: 8, border: '1px solid #d9d9d9', fontSize: 13 }}
        />
        {activeTab === 'dapps' && (
          <select
            value={categoryFilter} onChange={(e) => setCategoryFilter(e.target.value)}
            style={{ padding: '8px 14px', borderRadius: 8, border: '1px solid #d9d9d9', fontSize: 13, background: '#fff', minWidth: 140 }}
          >
            <option value="all">All Categories</option>
            <option value="DEX">DEX</option>
            <option value="NFT">NFT</option>
            <option value="Lending">Lending</option>
            <option value="Staking">Staking</option>
            <option value="Perps">Perps</option>
            <option value="Bridge">Bridge</option>
          </select>
        )}
      </div>

      {activeTab === 'dapps' ? (
        /* DApps Table */
        <div style={{ background: '#fff', borderRadius: 12, overflow: 'hidden', boxShadow: '0 1px 3px rgba(0,0,0,0.06)' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
            <thead>
              <tr>
                <th style={thStyle}>DApp</th>
                <th style={thStyle}>Category</th>
                <th style={thStyle}>Chain</th>
                <th style={thStyle}>Users</th>
                <th style={thStyle}>Volume (24h)</th>
                <th style={thStyle}>Status</th>
                <th style={thStyle}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredDapps.map((dapp) => (
                <tr key={dapp.id}
                  onMouseEnter={(e) => (e.currentTarget.style.background = '#fafbfc')}
                  onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
                >
                  <td style={tdStyle}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                      <div style={{
                        width: 36, height: 36, borderRadius: 8,
                        background: `linear-gradient(135deg, ${CATEGORY_COLORS[dapp.category] || '#ccc'}22, ${CATEGORY_COLORS[dapp.category] || '#ccc'}44)`,
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        fontSize: 11, fontWeight: 700, color: CATEGORY_COLORS[dapp.category] || '#6a7587',
                        border: `1px solid ${CATEGORY_COLORS[dapp.category] || '#ccc'}33`,
                      }}>
                        {dapp.icon}
                      </div>
                      <div>
                        <div style={{ fontWeight: 600, color: '#192945' }}>{dapp.name}</div>
                        <div style={{ fontSize: 11, color: '#8c95a6' }}>{dapp.url}</div>
                      </div>
                    </div>
                  </td>
                  <td style={tdStyle}>
                    <span style={{
                      padding: '3px 10px', borderRadius: 12, fontSize: 11, fontWeight: 600,
                      background: `${CATEGORY_COLORS[dapp.category]}15`,
                      color: CATEGORY_COLORS[dapp.category],
                    }}>
                      {dapp.category}
                    </span>
                  </td>
                  <td style={tdStyle}>{dapp.chain}</td>
                  <td style={{ ...tdStyle, fontWeight: 600 }}>{dapp.users}</td>
                  <td style={{ ...tdStyle, fontWeight: 600 }}>{dapp.volume}</td>
                  <td style={tdStyle}>
                    <span style={{
                      padding: '3px 10px', borderRadius: 12, fontSize: 11, fontWeight: 600,
                      ...STATUS_STYLES[dapp.status],
                    }}>
                      {dapp.status}
                    </span>
                  </td>
                  <td style={tdStyle}>
                    <div style={{ display: 'flex', gap: 6 }}>
                      <button style={{
                        padding: '4px 10px', borderRadius: 6, border: '1px solid #d9d9d9',
                        background: '#fff', fontSize: 11, cursor: 'pointer', color: '#4c65ff',
                      }}>
                        Edit
                      </button>
                      <button style={{
                        padding: '4px 10px', borderRadius: 6, border: '1px solid #ffccc7',
                        background: '#fff', fontSize: 11, cursor: 'pointer', color: '#cf1322',
                      }}>
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <div style={{
            display: 'flex', justifyContent: 'space-between', alignItems: 'center',
            padding: '12px 16px', borderTop: '1px solid #f0f0f0', fontSize: 13, color: '#6a7587',
          }}>
            <span>Showing {filteredDapps.length} of {MOCK_DAPPS.length} DApps</span>
          </div>
        </div>
      ) : (
        /* Review Queue Table */
        <div style={{ background: '#fff', borderRadius: 12, overflow: 'hidden', boxShadow: '0 1px 3px rgba(0,0,0,0.06)' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
            <thead>
              <tr>
                <th style={thStyle}>DApp</th>
                <th style={thStyle}>Category</th>
                <th style={thStyle}>Chain</th>
                <th style={thStyle}>Submitted By</th>
                <th style={thStyle}>Date</th>
                <th style={thStyle}>Status</th>
                <th style={thStyle}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredQueue.map((item) => (
                <tr key={item.id}
                  onMouseEnter={(e) => (e.currentTarget.style.background = '#fafbfc')}
                  onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
                >
                  <td style={tdStyle}>
                    <div style={{ fontWeight: 600, color: '#192945' }}>{item.name}</div>
                    <div style={{ fontSize: 11, color: '#8c95a6' }}>{item.url}</div>
                  </td>
                  <td style={tdStyle}>
                    <span style={{
                      padding: '3px 10px', borderRadius: 12, fontSize: 11, fontWeight: 600,
                      background: `${CATEGORY_COLORS[item.category] || '#ccc'}15`,
                      color: CATEGORY_COLORS[item.category] || '#6a7587',
                    }}>
                      {item.category}
                    </span>
                  </td>
                  <td style={tdStyle}>{item.chain}</td>
                  <td style={tdStyle}>{item.submittedBy}</td>
                  <td style={{ ...tdStyle, fontSize: 12, color: '#6a7587' }}>{item.submittedDate}</td>
                  <td style={tdStyle}>
                    <span style={{
                      padding: '3px 10px', borderRadius: 12, fontSize: 11, fontWeight: 600,
                      ...STATUS_STYLES[item.status],
                    }}>
                      {item.status.replace('_', ' ')}
                    </span>
                  </td>
                  <td style={tdStyle}>
                    <div style={{ display: 'flex', gap: 6 }}>
                      <button style={{
                        padding: '4px 10px', borderRadius: 6, border: '1px solid #b7eb8f',
                        background: '#f6ffed', fontSize: 11, cursor: 'pointer', color: '#389e0d', fontWeight: 600,
                      }}>
                        Approve
                      </button>
                      <button style={{
                        padding: '4px 10px', borderRadius: 6, border: '1px solid #ffccc7',
                        background: '#fff2f0', fontSize: 11, cursor: 'pointer', color: '#cf1322', fontWeight: 600,
                      }}>
                        Reject
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <div style={{ padding: '12px 16px', borderTop: '1px solid #f0f0f0', fontSize: 13, color: '#6a7587' }}>
            Showing {filteredQueue.length} of {REVIEW_QUEUE.length} submissions
          </div>
        </div>
      )}
    </div>
  );
}
