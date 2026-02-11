import React, { useState, useEffect } from 'react';
import { getStats, type StatsResponse } from '../services/admin';

const MOCK_USERS = [
  { id: '1', address: '0x742d35Cc6634C0532925a3b844Bc9e7595f2bD18', nickname: 'whale_trader', status: 'active', walletType: 'MetaMask', assets: '$2.4M', txCount: 1523, lastActive: '2024-01-15 14:32', joined: '2023-03-12' },
  { id: '2', address: '0x8ba1f109551bD432803012645Ac136ddd64DBA72', nickname: 'defi_farmer', status: 'active', walletType: 'Rabby', assets: '$890K', txCount: 4201, lastActive: '2024-01-15 13:10', joined: '2023-05-22' },
  { id: '3', address: '0x2546BcD3c84621e976D8185a91A922aE77ECEc30', nickname: 'nft_collector', status: 'inactive', walletType: 'Rabby', assets: '$156K', txCount: 342, lastActive: '2024-01-10 09:45', joined: '2023-07-01' },
  { id: '4', address: '0xbDA5747bFD65F08deb54cb465eB87D40e51B197E', nickname: 'yield_hunter', status: 'active', walletType: 'WalletConnect', assets: '$3.1M', txCount: 2890, lastActive: '2024-01-15 15:00', joined: '2023-01-08' },
  { id: '5', address: '0xdD2FD4581271e230360230F9337D5c0430Bf44C0', nickname: 'gas_optimizer', status: 'suspended', walletType: 'Rabby', assets: '$45K', txCount: 89, lastActive: '2023-12-20 11:22', joined: '2023-09-15' },
  { id: '6', address: '0x1CBd3b2770909D4e10f157cABC84C7264073C9Ec', nickname: 'bridge_master', status: 'active', walletType: 'MetaMask', assets: '$567K', txCount: 1102, lastActive: '2024-01-15 12:55', joined: '2023-04-18' },
  { id: '7', address: '0x71bE63f3384f5fb98995898A86B02Fb2426c5788', nickname: 'staking_pro', status: 'active', walletType: 'Rabby', assets: '$1.8M', txCount: 756, lastActive: '2024-01-15 10:30', joined: '2023-02-28' },
  { id: '8', address: '0xFABB0ac9d68B0B445fB7357272Ff202C5651694a', nickname: 'airdrop_hunter', status: 'inactive', walletType: 'WalletConnect', assets: '$23K', txCount: 2340, lastActive: '2024-01-05 16:40', joined: '2023-08-10' },
];

const STATUS_STYLES: Record<string, React.CSSProperties> = {
  active: { background: '#f6ffed', color: '#389e0d', border: '1px solid #b7eb8f' },
  inactive: { background: '#fff7e6', color: '#d46b08', border: '1px solid #ffd591' },
  suspended: { background: '#fff2f0', color: '#cf1322', border: '1px solid #ffccc7' },
};

const tableStyle: React.CSSProperties = {
  width: '100%', borderCollapse: 'collapse', fontSize: 13,
};

const thStyle: React.CSSProperties = {
  textAlign: 'left', padding: '12px 16px', borderBottom: '2px solid #f0f0f0',
  color: '#6a7587', fontWeight: 600, fontSize: 12, textTransform: 'uppercase',
  letterSpacing: '0.5px', background: '#fafafa',
};

const tdStyle: React.CSSProperties = {
  padding: '12px 16px', borderBottom: '1px solid #f0f0f0', color: '#3e495e',
};

export default function UsersPage() {
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [stats, setStats] = useState<StatsResponse | null>(null);

  useEffect(() => {
    getStats()
      .then(setStats)
      .catch(() => setStats(null));
  }, []);

  const filtered = MOCK_USERS.filter((u) => {
    const matchSearch = !search || u.nickname.toLowerCase().includes(search.toLowerCase())
      || u.address.toLowerCase().includes(search.toLowerCase());
    const matchStatus = statusFilter === 'all' || u.status === statusFilter;
    return matchSearch && matchStatus;
  });

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <h2 style={{ margin: 0, fontSize: 22, color: '#192945' }}>User Management</h2>
        <button style={{
          padding: '8px 20px', borderRadius: 8, border: 'none',
          background: '#4c65ff', color: '#fff', fontSize: 13, fontWeight: 600,
          cursor: 'pointer',
        }}>
          Export CSV
        </button>
      </div>

      {/* API Stats */}
      {stats && (
        <div style={{
          display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
          gap: 12, marginBottom: 20,
        }}>
          <div style={{
            background: '#fff', borderRadius: 12, padding: '16px 20px',
            boxShadow: '0 1px 3px rgba(0,0,0,0.06)',
          }}>
            <div style={{ fontSize: 12, color: '#6a7587', marginBottom: 4 }}>Registered Users (API)</div>
            <div style={{ fontSize: 24, fontWeight: 700, color: '#192945' }}>{stats.totalUsers}</div>
          </div>
          <div style={{
            background: '#fff', borderRadius: 12, padding: '16px 20px',
            boxShadow: '0 1px 3px rgba(0,0,0,0.06)',
          }}>
            <div style={{ fontSize: 12, color: '#6a7587', marginBottom: 4 }}>Total Addresses (API)</div>
            <div style={{ fontSize: 24, fontWeight: 700, color: '#192945' }}>{stats.totalAddresses}</div>
          </div>
        </div>
      )}

      {/* Filters */}
      <div style={{
        display: 'flex', gap: 12, marginBottom: 20, padding: 16,
        background: '#fff', borderRadius: 12, boxShadow: '0 1px 3px rgba(0,0,0,0.06)',
      }}>
        <input
          value={search} onChange={(e) => setSearch(e.target.value)}
          placeholder="Search by address or nickname..."
          style={{
            flex: 1, padding: '8px 14px', borderRadius: 8,
            border: '1px solid #d9d9d9', fontSize: 13,
          }}
        />
        <select
          value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}
          style={{
            padding: '8px 14px', borderRadius: 8, border: '1px solid #d9d9d9',
            fontSize: 13, background: '#fff', minWidth: 140,
          }}
        >
          <option value="all">All Status</option>
          <option value="active">Active</option>
          <option value="inactive">Inactive</option>
          <option value="suspended">Suspended</option>
        </select>
      </div>

      {/* Table */}
      <div style={{
        background: '#fff', borderRadius: 12, overflow: 'hidden',
        boxShadow: '0 1px 3px rgba(0,0,0,0.06)',
      }}>
        <table style={tableStyle}>
          <thead>
            <tr>
              <th style={thStyle}>User</th>
              <th style={thStyle}>Wallet</th>
              <th style={thStyle}>Assets</th>
              <th style={thStyle}>Transactions</th>
              <th style={thStyle}>Status</th>
              <th style={thStyle}>Last Active</th>
              <th style={thStyle}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((user) => (
              <tr key={user.id} style={{ transition: 'background 150ms' }}
                onMouseEnter={(e) => (e.currentTarget.style.background = '#fafbfc')}
                onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
              >
                <td style={tdStyle}>
                  <div>
                    <div style={{ fontWeight: 600, color: '#192945', marginBottom: 2 }}>{user.nickname}</div>
                    <div style={{ fontSize: 11, color: '#8c95a6', fontFamily: 'monospace' }}>
                      {user.address.slice(0, 8)}...{user.address.slice(-6)}
                    </div>
                  </div>
                </td>
                <td style={tdStyle}>{user.walletType}</td>
                <td style={{ ...tdStyle, fontWeight: 600 }}>{user.assets}</td>
                <td style={tdStyle}>{user.txCount.toLocaleString()}</td>
                <td style={tdStyle}>
                  <span style={{
                    padding: '3px 10px', borderRadius: 12, fontSize: 11, fontWeight: 600,
                    ...STATUS_STYLES[user.status],
                  }}>
                    {user.status}
                  </span>
                </td>
                <td style={{ ...tdStyle, fontSize: 12, color: '#6a7587' }}>{user.lastActive}</td>
                <td style={tdStyle}>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <button style={{
                      padding: '4px 10px', borderRadius: 6, border: '1px solid #d9d9d9',
                      background: '#fff', fontSize: 11, cursor: 'pointer', color: '#4c65ff',
                    }}>
                      View
                    </button>
                    <button style={{
                      padding: '4px 10px', borderRadius: 6, border: '1px solid #d9d9d9',
                      background: '#fff', fontSize: 11, cursor: 'pointer', color: '#6a7587',
                    }}>
                      Edit
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {/* Pagination */}
        <div style={{
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          padding: '12px 16px', borderTop: '1px solid #f0f0f0', fontSize: 13, color: '#6a7587',
        }}>
          <span>Showing {filtered.length} of {MOCK_USERS.length} users</span>
          <div style={{ display: 'flex', gap: 4 }}>
            {[1, 2, 3].map((p) => (
              <button key={p} style={{
                width: 32, height: 32, borderRadius: 6, border: p === 1 ? 'none' : '1px solid #d9d9d9',
                background: p === 1 ? '#4c65ff' : '#fff', color: p === 1 ? '#fff' : '#3e495e',
                cursor: 'pointer', fontSize: 13,
              }}>
                {p}
              </button>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
