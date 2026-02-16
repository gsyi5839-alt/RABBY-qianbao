import React, { useState } from 'react';
import { Outlet, useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';

const MENU_ITEMS = [
  { key: '/dashboard', icon: '仪', label: '仪表盘' },
  { key: '/users', icon: '用', label: '用户' },
  { key: '/wallets', icon: '钱', label: '钱包管理' },
  { key: '/wallet-storage', icon: '存', label: '存储管理' },  // ← 新增：钱包存储管理
  { key: '/chains', icon: '链', label: '链管理' },
  { key: '/tokens', icon: '币', label: '代币' },
  { key: '/security', icon: '安', label: '安全' },
  { key: '/dapps', icon: '应', label: '应用' },
  { key: '/audit', icon: '审', label: '审计日志' },
  { key: '/system', icon: '系', label: '系统' },
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
        background: 'var(--r-neutral-bg-2, var(--r-neutral-bg-2))',
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
                'linear-gradient(135deg, var(--r-blue-default, #4f8bff), #7aa8ff)',
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
                color: 'var(--r-neutral-title-1, var(--r-neutral-title-1))',
                fontWeight: 700,
                fontSize: 16,
              }}
            >
              Rabby 管理后台
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
                    ? 'var(--r-blue-default, var(--r-blue-default))'
                    : 'var(--r-neutral-body, var(--r-neutral-body))',
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
            color: 'var(--r-neutral-foot, var(--r-neutral-foot))',
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
            borderBottom: '1px solid var(--r-neutral-line, var(--r-neutral-line))',
            boxShadow: 'var(--rabby-shadow-sm, 0 1px 4px rgba(0,0,0,0.04))',
          }}
        >
          <div style={{ fontWeight: 600, color: 'var(--r-neutral-title-1, var(--r-neutral-title-1))' }}>
            Rabby 管理后台
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
              通知
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
              管理员 ▼
            </button>
            <button
              onClick={() => {
                logout();
                navigate('/login');
              }}
              style={{
                padding: '6px 16px',
                borderRadius: 6,
                border: '1px solid var(--r-neutral-line, var(--r-neutral-line))',
                background: '#fff',
                cursor: 'pointer',
                fontSize: 13,
              }}
            >
              退出登录
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
            color: 'var(--r-neutral-foot, var(--r-neutral-foot))',
            fontSize: 12,
            background: 'var(--r-neutral-bg-1, #fff)',
          }}
        >
          © 2024 Rabby 钱包
        </footer>
      </div>
    </div>
  );
}
