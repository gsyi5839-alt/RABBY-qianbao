import React, { useEffect, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';

const MOCK_ADMINS = [
  { id: '1', username: 'admin', email: 'admin@rabby.io', role: 'Super Admin', status: 'active', lastLogin: '2024-01-15 15:01', createdAt: '2023-01-01' },
  { id: '2', username: 'moderator', email: 'mod@rabby.io', role: 'Moderator', status: 'active', lastLogin: '2024-01-15 14:32', createdAt: '2023-06-15' },
  { id: '3', username: 'analyst', email: 'analyst@rabby.io', role: 'Read Only', status: 'active', lastLogin: '2024-01-14 10:20', createdAt: '2023-09-01' },
  { id: '4', username: 'security_lead', email: 'security@rabby.io', role: 'Security Admin', status: 'active', lastLogin: '2024-01-15 12:00', createdAt: '2023-04-10' },
  { id: '5', username: 'old_admin', email: 'old@rabby.io', role: 'Moderator', status: 'disabled', lastLogin: '2023-11-20 09:15', createdAt: '2023-02-20' },
];

const MOCK_ROLES = [
  { id: '1', name: 'Super Admin', description: 'Full system access', permissions: ['all'], userCount: 1, color: '#cf1322' },
  { id: '2', name: 'Security Admin', description: 'Security rules and phishing management', permissions: ['security.read', 'security.write', 'audit.read'], userCount: 1, color: '#d46b08' },
  { id: '3', name: 'Moderator', description: 'DApp and chain management', permissions: ['dapp.read', 'dapp.write', 'chain.read', 'chain.write', 'audit.read'], userCount: 2, color: '#4c65ff' },
  { id: '4', name: 'Read Only', description: 'View-only access to all sections', permissions: ['*.read'], userCount: 1, color: '#389e0d' },
];

const SYSTEM_SETTINGS = [
  { key: 'api_rate_limit', label: 'API Rate Limit', value: '200 req/min', category: 'Performance' },
  { key: 'session_timeout', label: 'Session Timeout', value: '30 minutes', category: 'Security' },
  { key: 'max_login_attempts', label: 'Max Login Attempts', value: '5', category: 'Security' },
  { key: 'auto_backup', label: 'Auto Backup', value: 'Enabled (Daily)', category: 'Maintenance' },
  { key: 'log_retention', label: 'Log Retention', value: '90 days', category: 'Maintenance' },
  { key: 'two_factor_auth', label: '2FA Requirement', value: 'Required for all admins', category: 'Security' },
  { key: 'cors_origins', label: 'CORS Allowed Origins', value: '*.rabby.io, localhost:3000', category: 'Network' },
  { key: 'webhook_url', label: 'Alert Webhook URL', value: 'https://hooks.slack.com/...', category: 'Notifications' },
];

const ROLE_STATUS_STYLES: Record<string, React.CSSProperties> = {
  active: { background: '#f6ffed', color: '#389e0d', border: '1px solid #b7eb8f' },
  disabled: { background: '#fff2f0', color: '#cf1322', border: '1px solid #ffccc7' },
};

const thStyle: React.CSSProperties = {
  textAlign: 'left', padding: '12px 16px', borderBottom: '2px solid #f0f0f0',
  color: '#6a7587', fontWeight: 600, fontSize: 12, textTransform: 'uppercase',
  letterSpacing: '0.5px', background: '#fafafa',
};

const tdStyle: React.CSSProperties = {
  padding: '12px 16px', borderBottom: '1px solid #f0f0f0', color: '#3e495e', fontSize: 13,
};

type SystemTab = 'settings' | 'admins' | 'roles';

export default function SystemPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const [activeTab, setActiveTab] = useState<SystemTab>('settings');

  useEffect(() => {
    if (location.pathname.includes('/system/admins')) {
      setActiveTab('admins');
    } else if (location.pathname.includes('/system/roles')) {
      setActiveTab('roles');
    } else {
      setActiveTab('settings');
    }
  }, [location.pathname]);

  const tabRoutes: Record<SystemTab, string> = {
    settings: '/system/config',
    admins: '/system/admins',
    roles: '/system/roles',
  };

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <h2 style={{ margin: 0, fontSize: 22, color: '#192945' }}>System Settings</h2>
        {activeTab === 'admins' && (
          <button style={{
            padding: '8px 20px', borderRadius: 8, border: 'none',
            background: '#4c65ff', color: '#fff', fontSize: 13, fontWeight: 600, cursor: 'pointer',
          }}>
            + Add Admin
          </button>
        )}
        {activeTab === 'roles' && (
          <button style={{
            padding: '8px 20px', borderRadius: 8, border: 'none',
            background: '#4c65ff', color: '#fff', fontSize: 13, fontWeight: 600, cursor: 'pointer',
          }}>
            + Add Role
          </button>
        )}
      </div>

      {/* Tabs */}
      <div style={{ display: 'flex', gap: 0, marginBottom: 20 }}>
        {([
          { key: 'settings' as const, label: 'General Settings' },
          { key: 'admins' as const, label: `Admin Accounts (${MOCK_ADMINS.length})` },
          { key: 'roles' as const, label: `Roles & Permissions (${MOCK_ROLES.length})` },
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

      {activeTab === 'settings' && (
        /* General Settings */
        <div style={{ background: '#fff', borderRadius: 12, overflow: 'hidden', boxShadow: '0 1px 3px rgba(0,0,0,0.06)' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
            <thead>
              <tr>
                <th style={thStyle}>Setting</th>
                <th style={thStyle}>Category</th>
                <th style={thStyle}>Current Value</th>
                <th style={thStyle}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {SYSTEM_SETTINGS.map((setting) => (
                <tr key={setting.key}
                  onMouseEnter={(e) => (e.currentTarget.style.background = '#fafbfc')}
                  onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
                >
                  <td style={tdStyle}>
                    <div style={{ fontWeight: 600, color: '#192945' }}>{setting.label}</div>
                    <div style={{ fontSize: 11, color: '#8c95a6', fontFamily: 'monospace', marginTop: 2 }}>
                      {setting.key}
                    </div>
                  </td>
                  <td style={tdStyle}>
                    <span style={{
                      padding: '3px 10px', borderRadius: 12, fontSize: 11, fontWeight: 600,
                      background: '#f0f2f5', color: '#3e495e',
                    }}>
                      {setting.category}
                    </span>
                  </td>
                  <td style={{ ...tdStyle, fontFamily: 'monospace', fontSize: 12 }}>{setting.value}</td>
                  <td style={tdStyle}>
                    <button style={{
                      padding: '4px 10px', borderRadius: 6, border: '1px solid #d9d9d9',
                      background: '#fff', fontSize: 11, cursor: 'pointer', color: '#4c65ff',
                    }}>
                      Edit
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <div style={{
            padding: '16px', borderTop: '1px solid #f0f0f0',
            display: 'flex', justifyContent: 'flex-end', gap: 8,
          }}>
            <button style={{
              padding: '8px 20px', borderRadius: 8, border: '1px solid #d9d9d9',
              background: '#fff', fontSize: 13, cursor: 'pointer', color: '#3e495e',
            }}>
              Reset Defaults
            </button>
            <button style={{
              padding: '8px 20px', borderRadius: 8, border: 'none',
              background: '#4c65ff', color: '#fff', fontSize: 13, fontWeight: 600, cursor: 'pointer',
            }}>
              Save Changes
            </button>
          </div>
        </div>
      )}

      {activeTab === 'admins' && (
        /* Admin Accounts */
        <div style={{ background: '#fff', borderRadius: 12, overflow: 'hidden', boxShadow: '0 1px 3px rgba(0,0,0,0.06)' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
            <thead>
              <tr>
                <th style={thStyle}>Username</th>
                <th style={thStyle}>Email</th>
                <th style={thStyle}>Role</th>
                <th style={thStyle}>Status</th>
                <th style={thStyle}>Last Login</th>
                <th style={thStyle}>Created</th>
                <th style={thStyle}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {MOCK_ADMINS.map((admin) => (
                <tr key={admin.id}
                  onMouseEnter={(e) => (e.currentTarget.style.background = '#fafbfc')}
                  onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
                >
                  <td style={tdStyle}>
                    <span style={{ fontWeight: 600, color: '#192945' }}>{admin.username}</span>
                  </td>
                  <td style={{ ...tdStyle, color: '#6a7587' }}>{admin.email}</td>
                  <td style={tdStyle}>
                    <span style={{
                      padding: '3px 10px', borderRadius: 12, fontSize: 11, fontWeight: 600,
                      background: `${MOCK_ROLES.find((r) => r.name === admin.role)?.color || '#6a7587'}15`,
                      color: MOCK_ROLES.find((r) => r.name === admin.role)?.color || '#6a7587',
                    }}>
                      {admin.role}
                    </span>
                  </td>
                  <td style={tdStyle}>
                    <span style={{
                      padding: '3px 10px', borderRadius: 12, fontSize: 11, fontWeight: 600,
                      ...ROLE_STATUS_STYLES[admin.status],
                    }}>
                      {admin.status}
                    </span>
                  </td>
                  <td style={{ ...tdStyle, fontSize: 12, color: '#6a7587' }}>{admin.lastLogin}</td>
                  <td style={{ ...tdStyle, fontSize: 12, color: '#6a7587' }}>{admin.createdAt}</td>
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
                        {admin.status === 'active' ? 'Disable' : 'Enable'}
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <div style={{ padding: '12px 16px', borderTop: '1px solid #f0f0f0', fontSize: 13, color: '#6a7587' }}>
            Showing {MOCK_ADMINS.length} admin accounts
          </div>
        </div>
      )}

      {activeTab === 'roles' && (
        /* Roles & Permissions */
        <div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: 16 }}>
            {MOCK_ROLES.map((role) => (
              <div key={role.id} style={{
                background: '#fff', borderRadius: 12, padding: 24,
                boxShadow: '0 1px 3px rgba(0,0,0,0.06)',
                borderLeft: `4px solid ${role.color}`,
              }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 12 }}>
                  <div>
                    <h3 style={{ margin: '0 0 4px', fontSize: 16, color: '#192945' }}>{role.name}</h3>
                    <p style={{ margin: 0, fontSize: 13, color: '#6a7587' }}>{role.description}</p>
                  </div>
                  <span style={{
                    padding: '2px 10px', borderRadius: 12, fontSize: 11, fontWeight: 600,
                    background: `${role.color}15`, color: role.color,
                  }}>
                    {role.userCount} user{role.userCount !== 1 ? 's' : ''}
                  </span>
                </div>

                <div style={{ marginBottom: 16 }}>
                  <div style={{ fontSize: 12, fontWeight: 600, color: '#6a7587', marginBottom: 8, textTransform: 'uppercase', letterSpacing: '0.5px' }}>
                    Permissions
                  </div>
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                    {role.permissions.map((perm) => (
                      <span key={perm} style={{
                        padding: '3px 8px', borderRadius: 4, fontSize: 11,
                        background: '#f0f2f5', color: '#3e495e', fontFamily: 'monospace',
                      }}>
                        {perm}
                      </span>
                    ))}
                  </div>
                </div>

                <div style={{ display: 'flex', gap: 8, borderTop: '1px solid #f0f0f0', paddingTop: 12 }}>
                  <button style={{
                    padding: '6px 14px', borderRadius: 6, border: '1px solid #d9d9d9',
                    background: '#fff', fontSize: 12, cursor: 'pointer', color: '#4c65ff',
                  }}>
                    Edit Permissions
                  </button>
                  {role.name !== 'Super Admin' && (
                    <button style={{
                      padding: '6px 14px', borderRadius: 6, border: '1px solid #ffccc7',
                      background: '#fff', fontSize: 12, cursor: 'pointer', color: '#cf1322',
                    }}>
                      Delete
                    </button>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
