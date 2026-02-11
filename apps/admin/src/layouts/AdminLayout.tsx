import React, { useState } from 'react';
import { Outlet, useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';

const MENU_ITEMS = [
  { key: '/dashboard', icon: '\u{1F4CA}', label: 'Dashboard' },
  { key: '/users', icon: '\u{1F465}', label: 'Users' },
  { key: '/chains', icon: '\u26D3\uFE0F', label: 'Chains' },
  { key: '/tokens', icon: '\u{1FA99}', label: 'Tokens' },
  { key: '/security', icon: '\u{1F512}', label: 'Security' },
  { key: '/dapps', icon: '\u{1F4F1}', label: 'DApps' },
  { key: '/audit', icon: '\u{1F4DC}', label: 'Audit Log' },
  { key: '/system', icon: '\u2699\uFE0F', label: 'System' },
];

export default function AdminLayout() {
  const navigate = useNavigate();
  const location = useLocation();
  const { logout } = useAuth();
  const [collapsed, setCollapsed] = useState(false);

  return (
    <div
      style={{
        display: 'flex',
        minHeight: '100vh',
        background: 'var(--r-neutral-bg-2, #f2f4f7)',
      }}
    >
      {/* Sidebar */}
      <aside
        style={{
          width: collapsed ? 64 : 256,
          background: 'var(--r-neutral-bg-1, #fff)',
          borderRight: '1px solid var(--r-neutral-line, #e0e5ec)',
          transition: 'width 200ms',
          display: 'flex',
          flexDirection: 'column',
          flexShrink: 0,
        }}
      >
        <div
          style={{
            height: 'var(--rabby-topbar-height, 64px)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: collapsed ? 'center' : 'flex-start',
            padding: collapsed ? 0 : '0 24px',
            borderBottom: '1px solid var(--r-neutral-line, #e0e5ec)',
            gap: 10,
          }}
        >
          <div
            style={{
              width: 28,
              height: 28,
              borderRadius: 8,
              background:
                'linear-gradient(135deg, var(--r-blue-default, #4c65ff), #7084ff)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#fff',
              fontWeight: 700,
              fontSize: 14,
            }}
          >
            R
          </div>
          {!collapsed && (
            <span
              style={{
                color: 'var(--r-neutral-title-1, #192945)',
                fontWeight: 700,
                fontSize: 16,
              }}
            >
              Rabby Admin
            </span>
          )}
        </div>
        <nav style={{ flex: 1, padding: '12px 8px' }}>
          {MENU_ITEMS.map((item) => {
            const active = location.pathname.startsWith(item.key);
            return (
              <button
                key={item.key}
                onClick={() => navigate(item.key)}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 12,
                  width: '100%',
                  padding: collapsed ? '12px 0' : '12px 16px',
                  justifyContent: collapsed ? 'center' : 'flex-start',
                  background: active
                    ? 'var(--r-blue-light-1, #edf0ff)'
                    : 'transparent',
                  color: active
                    ? 'var(--r-blue-default, #4c65ff)'
                    : 'var(--r-neutral-body, #3e495e)',
                  border: 'none',
                  borderRadius: 8,
                  cursor: 'pointer',
                  fontSize: 14,
                  marginBottom: 2,
                }}
              >
                <span style={{ fontSize: 16 }}>{item.icon}</span>
                {!collapsed && <span>{item.label}</span>}
              </button>
            );
          })}
        </nav>
        <button
          onClick={() => setCollapsed(!collapsed)}
          style={{
            padding: 16,
            background: 'none',
            border: 'none',
            borderTop: '1px solid var(--r-neutral-line, #e0e5ec)',
            color: 'var(--r-neutral-foot, #6a7587)',
            cursor: 'pointer',
          }}
        >
          {collapsed ? '\u2192' : '\u2190'}
        </button>
      </aside>

      {/* Main */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
        <header
          style={{
            height: 'var(--rabby-topbar-height, 64px)',
            background: 'var(--r-neutral-bg-1, #fff)',
            padding: '0 24px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            borderBottom: '1px solid var(--r-neutral-line, #f0f0f0)',
            boxShadow: 'var(--rabby-shadow-sm, 0 1px 4px rgba(0,0,0,0.04))',
          }}
        >
          <div style={{ fontWeight: 600, color: 'var(--r-neutral-title-1, #192945)' }}>
            Rabby Admin
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <button
              style={{
                border: '1px solid var(--r-neutral-line, #e0e5ec)',
                background: '#fff',
                borderRadius: 6,
                padding: '6px 10px',
                cursor: 'pointer',
                fontSize: 12,
              }}
            >
              \u{1F514}
            </button>
            <button
              style={{
                border: '1px solid var(--r-neutral-line, #e0e5ec)',
                background: '#fff',
                borderRadius: 6,
                padding: '6px 10px',
                cursor: 'pointer',
                fontSize: 12,
              }}
            >
              admin \u25BE
            </button>
            <button
              onClick={() => {
                logout();
                navigate('/login');
              }}
              style={{
                padding: '6px 16px',
                borderRadius: 6,
                border: '1px solid var(--r-neutral-line, #d9d9d9)',
                background: '#fff',
                cursor: 'pointer',
                fontSize: 13,
              }}
            >
              Logout
            </button>
          </div>
        </header>
        <main style={{ flex: 1, padding: 24, overflow: 'auto' }}>
          <Outlet />
        </main>
        <footer
          style={{
            padding: '12px 24px',
            borderTop: '1px solid var(--r-neutral-line, #e0e5ec)',
            color: 'var(--r-neutral-foot, #6a7587)',
            fontSize: 12,
            background: 'var(--r-neutral-bg-1, #fff)',
          }}
        >
          © 2024 Rabby Wallet
        </footer>
      </div>
    </div>
  );
}
