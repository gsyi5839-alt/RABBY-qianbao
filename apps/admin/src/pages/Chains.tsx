import React, { useState } from 'react';

const MOCK_CHAINS = [
  { id: '1', chainId: 1, name: 'Ethereum', symbol: 'ETH', rpcUrl: 'https://eth-mainnet.g.alchemy.com/v2/...', explorerUrl: 'https://etherscan.io', rpcStatus: 'healthy', enabled: true, order: 1, latency: '45ms', blockHeight: '19,234,567' },
  { id: '2', chainId: 42161, name: 'Arbitrum One', symbol: 'ETH', rpcUrl: 'https://arb1.arbitrum.io/rpc', explorerUrl: 'https://arbiscan.io', rpcStatus: 'healthy', enabled: true, order: 2, latency: '32ms', blockHeight: '178,901,234' },
  { id: '3', chainId: 56, name: 'BNB Smart Chain', symbol: 'BNB', rpcUrl: 'https://bsc-dataseed.binance.org', explorerUrl: 'https://bscscan.com', rpcStatus: 'degraded', enabled: true, order: 3, latency: '120ms', blockHeight: '35,678,901' },
  { id: '4', chainId: 137, name: 'Polygon', symbol: 'MATIC', rpcUrl: 'https://polygon-rpc.com', explorerUrl: 'https://polygonscan.com', rpcStatus: 'healthy', enabled: true, order: 4, latency: '28ms', blockHeight: '52,345,678' },
  { id: '5', chainId: 10, name: 'Optimism', symbol: 'ETH', rpcUrl: 'https://mainnet.optimism.io', explorerUrl: 'https://optimistic.etherscan.io', rpcStatus: 'healthy', enabled: true, order: 5, latency: '38ms', blockHeight: '115,234,567' },
  { id: '6', chainId: 43114, name: 'Avalanche', symbol: 'AVAX', rpcUrl: 'https://api.avax.network/ext/bc/C/rpc', explorerUrl: 'https://snowtrace.io', rpcStatus: 'healthy', enabled: false, order: 6, latency: '55ms', blockHeight: '40,123,456' },
  { id: '7', chainId: 250, name: 'Fantom', symbol: 'FTM', rpcUrl: 'https://rpc.ftm.tools', explorerUrl: 'https://ftmscan.com', rpcStatus: 'down', enabled: false, order: 7, latency: '-', blockHeight: '-' },
  { id: '8', chainId: 324, name: 'zkSync Era', symbol: 'ETH', rpcUrl: 'https://mainnet.era.zksync.io', explorerUrl: 'https://explorer.zksync.io', rpcStatus: 'healthy', enabled: true, order: 8, latency: '41ms', blockHeight: '28,456,789' },
];

const RPC_STATUS_STYLES: Record<string, React.CSSProperties> = {
  healthy: { background: '#f6ffed', color: '#389e0d', border: '1px solid #b7eb8f' },
  degraded: { background: '#fff7e6', color: '#d46b08', border: '1px solid #ffd591' },
  down: { background: '#fff2f0', color: '#cf1322', border: '1px solid #ffccc7' },
};

const thStyle: React.CSSProperties = {
  textAlign: 'left', padding: '12px 16px', borderBottom: '2px solid #f0f0f0',
  color: '#6a7587', fontWeight: 600, fontSize: 12, textTransform: 'uppercase',
  letterSpacing: '0.5px', background: '#fafafa',
};

const tdStyle: React.CSSProperties = {
  padding: '12px 16px', borderBottom: '1px solid #f0f0f0', color: '#3e495e', fontSize: 13,
};

export default function ChainsPage() {
  const [chains, setChains] = useState(MOCK_CHAINS);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');

  const filtered = chains.filter((c) => {
    const matchSearch = !search || c.name.toLowerCase().includes(search.toLowerCase())
      || c.chainId.toString().includes(search);
    const matchStatus = statusFilter === 'all' || c.rpcStatus === statusFilter;
    return matchSearch && matchStatus;
  });

  const toggleEnabled = (id: string) => {
    setChains((prev) => prev.map((c) => c.id === id ? { ...c, enabled: !c.enabled } : c));
  };

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <h2 style={{ margin: 0, fontSize: 22, color: '#192945' }}>Chain Configuration</h2>
        <button style={{
          padding: '8px 20px', borderRadius: 8, border: 'none',
          background: '#4c65ff', color: '#fff', fontSize: 13, fontWeight: 600, cursor: 'pointer',
        }}>
          + Add Chain
        </button>
      </div>

      {/* Summary Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 20 }}>
        {[
          { label: 'Total Chains', value: chains.length, color: '#4c65ff' },
          { label: 'Enabled', value: chains.filter((c) => c.enabled).length, color: '#2abb7f' },
          { label: 'Healthy', value: chains.filter((c) => c.rpcStatus === 'healthy').length, color: '#389e0d' },
          { label: 'Issues', value: chains.filter((c) => c.rpcStatus !== 'healthy').length, color: '#ff4d4f' },
        ].map((s) => (
          <div key={s.label} style={{
            background: '#fff', borderRadius: 10, padding: '16px 20px',
            boxShadow: '0 1px 3px rgba(0,0,0,0.06)',
          }}>
            <div style={{ fontSize: 12, color: '#6a7587', marginBottom: 4 }}>{s.label}</div>
            <div style={{ fontSize: 24, fontWeight: 700, color: s.color }}>{s.value}</div>
          </div>
        ))}
      </div>

      {/* Filters */}
      <div style={{
        display: 'flex', gap: 12, marginBottom: 20, padding: 16,
        background: '#fff', borderRadius: 12, boxShadow: '0 1px 3px rgba(0,0,0,0.06)',
      }}>
        <input
          value={search} onChange={(e) => setSearch(e.target.value)}
          placeholder="Search by chain name or ID..."
          style={{ flex: 1, padding: '8px 14px', borderRadius: 8, border: '1px solid #d9d9d9', fontSize: 13 }}
        />
        <select
          value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}
          style={{ padding: '8px 14px', borderRadius: 8, border: '1px solid #d9d9d9', fontSize: 13, background: '#fff', minWidth: 140 }}
        >
          <option value="all">All Status</option>
          <option value="healthy">Healthy</option>
          <option value="degraded">Degraded</option>
          <option value="down">Down</option>
        </select>
      </div>

      {/* Table */}
      <div style={{ background: '#fff', borderRadius: 12, overflow: 'hidden', boxShadow: '0 1px 3px rgba(0,0,0,0.06)' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
          <thead>
            <tr>
              <th style={thStyle}>Chain</th>
              <th style={thStyle}>Chain ID</th>
              <th style={thStyle}>Symbol</th>
              <th style={thStyle}>RPC Status</th>
              <th style={thStyle}>Latency</th>
              <th style={thStyle}>Block Height</th>
              <th style={thStyle}>Enabled</th>
              <th style={thStyle}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((chain) => (
              <tr key={chain.id}
                onMouseEnter={(e) => (e.currentTarget.style.background = '#fafbfc')}
                onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
              >
                <td style={tdStyle}>
                  <div style={{ fontWeight: 600, color: '#192945' }}>{chain.name}</div>
                  <div style={{ fontSize: 11, color: '#8c95a6', fontFamily: 'monospace', marginTop: 2 }}>
                    {chain.rpcUrl.length > 40 ? chain.rpcUrl.slice(0, 40) + '...' : chain.rpcUrl}
                  </div>
                </td>
                <td style={tdStyle}>
                  <span style={{
                    fontFamily: 'monospace', background: '#f0f2f5', padding: '2px 8px',
                    borderRadius: 4, fontSize: 12,
                  }}>
                    {chain.chainId}
                  </span>
                </td>
                <td style={{ ...tdStyle, fontWeight: 600 }}>{chain.symbol}</td>
                <td style={tdStyle}>
                  <span style={{
                    padding: '3px 10px', borderRadius: 12, fontSize: 11, fontWeight: 600,
                    ...RPC_STATUS_STYLES[chain.rpcStatus],
                  }}>
                    {chain.rpcStatus}
                  </span>
                </td>
                <td style={{ ...tdStyle, fontFamily: 'monospace', fontSize: 12 }}>{chain.latency}</td>
                <td style={{ ...tdStyle, fontFamily: 'monospace', fontSize: 12 }}>{chain.blockHeight}</td>
                <td style={tdStyle}>
                  <button
                    onClick={() => toggleEnabled(chain.id)}
                    style={{
                      width: 40, height: 22, borderRadius: 11, border: 'none', cursor: 'pointer',
                      background: chain.enabled ? '#4c65ff' : '#d9d9d9',
                      position: 'relative', transition: 'background 200ms',
                    }}
                  >
                    <span style={{
                      position: 'absolute', top: 2, width: 18, height: 18,
                      borderRadius: '50%', background: '#fff', transition: 'left 200ms',
                      left: chain.enabled ? 20 : 2,
                      boxShadow: '0 1px 3px rgba(0,0,0,0.2)',
                    }} />
                  </button>
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
          <span>Showing {filtered.length} of {chains.length} chains</span>
        </div>
      </div>
    </div>
  );
}
