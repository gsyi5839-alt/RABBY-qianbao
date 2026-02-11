import React from 'react';
import { Outlet, useNavigate, useLocation } from 'react-router-dom';

const SETTINGS_SECTIONS = [
  {
    title: 'General',
    items: [
      { key: 'address', icon: '\u{1F4CB}', label: 'Address Management', desc: 'Manage your wallet addresses' },
      { key: 'chain-list', icon: '\u26D3\uFE0F', label: 'Chain List', desc: 'Manage supported chains' },
    ],
  },
  {
    title: 'Network',
    items: [
      { key: '/custom-rpc', icon: '\u{1F517}', label: 'Custom RPC', desc: 'Configure custom RPC endpoints', absolute: true },
    ],
  },
  {
    title: 'Security',
    items: [
      { key: 'advanced', icon: '\u{1F512}', label: 'Advanced Settings', desc: 'Security and privacy options' },
      { key: 'sites', icon: '\u{1F310}', label: 'Connected Sites', desc: 'Manage DApp connections' },
    ],
  },
];

export default function Settings() {
  const navigate = useNavigate();
  const location = useLocation();

  // If on a sub-route, show the Outlet
  const isSubRoute = location.pathname !== '/settings' && location.pathname !== '/settings/';
  if (isSubRoute) {
    return (
      <div>
        <button
          onClick={() => navigate('/settings')}
          style={{
            display: 'flex', alignItems: 'center', gap: 6,
            background: 'none', border: 'none', cursor: 'pointer',
            color: 'var(--r-blue-default, #4c65ff)', fontSize: 14,
            marginBottom: 16, padding: 0,
          }}
        >
          &larr; Back to Settings
        </button>
        <Outlet />
      </div>
    );
  }

  return (
    <div>
      <h2 style={{
        fontSize: 20, fontWeight: 600, margin: '0 0 24px',
        color: 'var(--r-neutral-title-1, #192945)',
      }}>
        Settings
      </h2>

      {SETTINGS_SECTIONS.map((section) => (
        <div key={section.title} style={{ marginBottom: 24 }}>
          <div style={{
            fontSize: 13, fontWeight: 600,
            color: 'var(--r-neutral-foot, #6a7587)',
            marginBottom: 8, paddingLeft: 4,
            textTransform: 'uppercase' as const,
            letterSpacing: '0.5px',
          }}>
            {section.title}
          </div>
          <div style={{
            background: 'var(--r-neutral-card-1, #fff)',
            borderRadius: 16,
            overflow: 'hidden',
            boxShadow: 'var(--rabby-shadow-sm, 0 2px 4px rgba(0,0,0,0.04))',
          }}>
            {section.items.map((item, i) => (
              <button
                key={item.key}
                onClick={() => navigate(item.absolute ? item.key : `/settings/${item.key}`)}
                style={{
                  display: 'flex', alignItems: 'center', gap: 14,
                  width: '100%', padding: '16px 20px',
                  background: 'transparent',
                  border: 'none',
                  borderBottom: i < section.items.length - 1 ? '1px solid var(--r-neutral-line, #e0e5ec)' : 'none',
                  cursor: 'pointer',
                  textAlign: 'left' as const,
                }}
              >
                <span style={{
                  width: 40, height: 40, borderRadius: 10,
                  background: 'var(--r-blue-light-1, #edf0ff)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 20, flexShrink: 0,
                }}>
                  {item.icon}
                </span>
                <div style={{ flex: 1 }}>
                  <div style={{
                    fontWeight: 600, fontSize: 15,
                    color: 'var(--r-neutral-title-1, #192945)',
                    marginBottom: 2,
                  }}>
                    {item.label}
                  </div>
                  <div style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)' }}>
                    {item.desc}
                  </div>
                </div>
                <span style={{ color: 'var(--r-neutral-foot, #6a7587)', fontSize: 16 }}>&rsaquo;</span>
              </button>
            ))}
          </div>
        </div>
      ))}

      {/* About */}
      <div style={{
        background: 'var(--r-neutral-card-1, #fff)',
        borderRadius: 16, padding: 20,
        boxShadow: 'var(--rabby-shadow-sm, 0 2px 4px rgba(0,0,0,0.04))',
        textAlign: 'center' as const,
      }}>
        <div style={{ fontSize: 13, color: 'var(--r-neutral-foot, #6a7587)' }}>
          Rabby Wallet v0.93.77
        </div>
      </div>
    </div>
  );
}
