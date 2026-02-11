import React, { useState } from 'react';

const MOCK_LOGS = [
  { id: '1', timestamp: '2024-01-15 15:01:23', user: 'admin', action: 'chain.update', resource: 'Ethereum RPC Config', details: 'Changed RPC endpoint to alchemy', ip: '192.168.1.100', status: 'success' },
  { id: '2', timestamp: '2024-01-15 14:55:10', user: 'admin', action: 'security.create', resource: 'Approval Revoke Warning', details: 'Created new security rule', ip: '192.168.1.100', status: 'success' },
  { id: '3', timestamp: '2024-01-15 14:32:45', user: 'moderator', action: 'dapp.update', resource: 'Uniswap', details: 'Updated DApp description and icon', ip: '10.0.0.52', status: 'success' },
  { id: '4', timestamp: '2024-01-15 14:20:00', user: 'admin', action: 'security.trigger', resource: 'Large Transfer Alert', details: 'Manual trigger for testing', ip: '192.168.1.100', status: 'success' },
  { id: '5', timestamp: '2024-01-15 13:45:33', user: 'system', action: 'chain.healthcheck', resource: 'BSC RPC', details: 'Health check failed - timeout', ip: 'system', status: 'failure' },
  { id: '6', timestamp: '2024-01-15 13:10:12', user: 'admin', action: 'user.suspend', resource: 'gas_optimizer (0xdD2F...44C0)', details: 'Suspicious activity detected', ip: '192.168.1.100', status: 'success' },
  { id: '7', timestamp: '2024-01-15 12:45:00', user: 'system', action: 'phishing.detect', resource: 'uniswap-airdrop.xyz', details: 'Auto-detected phishing domain', ip: 'system', status: 'success' },
  { id: '8', timestamp: '2024-01-15 12:30:18', user: 'admin', action: 'auth.login', resource: 'Admin Panel', details: 'Successful login', ip: '192.168.1.100', status: 'success' },
  { id: '9', timestamp: '2024-01-15 11:22:05', user: 'moderator', action: 'dapp.create', resource: 'NewDEX Protocol', details: 'Submitted for review', ip: '10.0.0.52', status: 'success' },
  { id: '10', timestamp: '2024-01-15 10:15:40', user: 'admin', action: 'system.config', resource: 'Rate Limit', details: 'Updated API rate limit from 100 to 200/min', ip: '192.168.1.100', status: 'success' },
  { id: '11', timestamp: '2024-01-15 09:30:00', user: 'system', action: 'backup.complete', resource: 'Database', details: 'Daily backup completed successfully', ip: 'system', status: 'success' },
  { id: '12', timestamp: '2024-01-15 08:00:00', user: 'admin', action: 'auth.login', resource: 'Admin Panel', details: 'Failed login attempt', ip: '203.0.113.42', status: 'failure' },
];

const ACTION_COLORS: Record<string, string> = {
  'chain': '#627EEA',
  'security': '#ff6b6b',
  'dapp': '#8b5cf6',
  'user': '#2abb7f',
  'auth': '#4c65ff',
  'system': '#6a7587',
  'phishing': '#ff4d4f',
  'backup': '#28A0F0',
};

const thStyle: React.CSSProperties = {
  textAlign: 'left', padding: '12px 16px', borderBottom: '2px solid #f0f0f0',
  color: '#6a7587', fontWeight: 600, fontSize: 12, textTransform: 'uppercase',
  letterSpacing: '0.5px', background: '#fafafa',
};

const tdStyle: React.CSSProperties = {
  padding: '12px 16px', borderBottom: '1px solid #f0f0f0', color: '#3e495e', fontSize: 13,
};

export default function AuditPage() {
  const [search, setSearch] = useState('');
  const [actionFilter, setActionFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');

  const filtered = MOCK_LOGS.filter((log) => {
    const matchSearch = !search
      || log.user.toLowerCase().includes(search.toLowerCase())
      || log.resource.toLowerCase().includes(search.toLowerCase())
      || log.details.toLowerCase().includes(search.toLowerCase());
    const matchAction = actionFilter === 'all' || log.action.startsWith(actionFilter);
    const matchStatus = statusFilter === 'all' || log.status === statusFilter;
    return matchSearch && matchAction && matchStatus;
  });

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <h2 style={{ margin: 0, fontSize: 22, color: '#192945' }}>Audit Log</h2>
        <button style={{
          padding: '8px 20px', borderRadius: 8, border: '1px solid #d9d9d9',
          background: '#fff', fontSize: 13, fontWeight: 500, cursor: 'pointer', color: '#3e495e',
        }}>
          Export Logs
        </button>
      </div>

      {/* Summary */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 20 }}>
        {[
          { label: 'Total Events', value: MOCK_LOGS.length.toString(), color: '#4c65ff' },
          { label: 'Success', value: MOCK_LOGS.filter((l) => l.status === 'success').length.toString(), color: '#2abb7f' },
          { label: 'Failures', value: MOCK_LOGS.filter((l) => l.status === 'failure').length.toString(), color: '#ff4d4f' },
          { label: 'Active Users', value: [...new Set(MOCK_LOGS.map((l) => l.user))].length.toString(), color: '#8b5cf6' },
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
          placeholder="Search logs by user, resource, or details..."
          style={{ flex: 1, padding: '8px 14px', borderRadius: 8, border: '1px solid #d9d9d9', fontSize: 13 }}
        />
        <select
          value={actionFilter} onChange={(e) => setActionFilter(e.target.value)}
          style={{ padding: '8px 14px', borderRadius: 8, border: '1px solid #d9d9d9', fontSize: 13, background: '#fff', minWidth: 140 }}
        >
          <option value="all">All Actions</option>
          <option value="chain">Chain</option>
          <option value="security">Security</option>
          <option value="dapp">DApp</option>
          <option value="user">User</option>
          <option value="auth">Auth</option>
          <option value="system">System</option>
        </select>
        <select
          value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}
          style={{ padding: '8px 14px', borderRadius: 8, border: '1px solid #d9d9d9', fontSize: 13, background: '#fff', minWidth: 120 }}
        >
          <option value="all">All Status</option>
          <option value="success">Success</option>
          <option value="failure">Failure</option>
        </select>
      </div>

      {/* Table */}
      <div style={{ background: '#fff', borderRadius: 12, overflow: 'hidden', boxShadow: '0 1px 3px rgba(0,0,0,0.06)' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
          <thead>
            <tr>
              <th style={thStyle}>Timestamp</th>
              <th style={thStyle}>User</th>
              <th style={thStyle}>Action</th>
              <th style={thStyle}>Resource</th>
              <th style={thStyle}>Details</th>
              <th style={thStyle}>IP Address</th>
              <th style={thStyle}>Status</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((log) => {
              const actionCategory = log.action.split('.')[0];
              return (
                <tr key={log.id}
                  onMouseEnter={(e) => (e.currentTarget.style.background = '#fafbfc')}
                  onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
                >
                  <td style={{ ...tdStyle, fontSize: 12, color: '#6a7587', fontFamily: 'monospace', whiteSpace: 'nowrap' }}>
                    {log.timestamp}
                  </td>
                  <td style={tdStyle}>
                    <span style={{ fontWeight: 600, color: '#192945' }}>{log.user}</span>
                  </td>
                  <td style={tdStyle}>
                    <span style={{
                      padding: '3px 10px', borderRadius: 12, fontSize: 11, fontWeight: 600,
                      background: `${ACTION_COLORS[actionCategory] || '#6a7587'}15`,
                      color: ACTION_COLORS[actionCategory] || '#6a7587',
                    }}>
                      {log.action}
                    </span>
                  </td>
                  <td style={{ ...tdStyle, fontWeight: 500 }}>{log.resource}</td>
                  <td style={{ ...tdStyle, color: '#6a7587', maxWidth: 250, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {log.details}
                  </td>
                  <td style={{ ...tdStyle, fontFamily: 'monospace', fontSize: 12, color: '#6a7587' }}>
                    {log.ip}
                  </td>
                  <td style={tdStyle}>
                    <span style={{
                      padding: '3px 10px', borderRadius: 12, fontSize: 11, fontWeight: 600,
                      background: log.status === 'success' ? '#f6ffed' : '#fff2f0',
                      color: log.status === 'success' ? '#389e0d' : '#cf1322',
                      border: log.status === 'success' ? '1px solid #b7eb8f' : '1px solid #ffccc7',
                    }}>
                      {log.status}
                    </span>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
        <div style={{
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          padding: '12px 16px', borderTop: '1px solid #f0f0f0', fontSize: 13, color: '#6a7587',
        }}>
          <span>Showing {filtered.length} of {MOCK_LOGS.length} events</span>
          <div style={{ display: 'flex', gap: 4 }}>
            {[1, 2, 3, 4, 5].map((p) => (
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
