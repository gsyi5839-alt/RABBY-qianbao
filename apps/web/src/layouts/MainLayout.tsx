import React, { useState } from 'react';
import { Outlet, useNavigate, useLocation, Link } from 'react-router-dom';
import { useWallet } from '../contexts/WalletContext';
import { useChainContext } from '../contexts/ChainContext';
import { useSettings } from '../contexts/SettingsContext';

const NAV_ITEMS = [
  { key: '/', icon: '🏠', label: 'Dashboard' },
  { key: '/send-token', icon: '↑', label: 'Send' },
  { key: '/receive', icon: '↓', label: 'Receive' },
  { key: '/dex-swap', icon: '🔄', label: 'Swap' },
  { key: '/bridge', icon: '🌉', label: 'Bridge' },
  { key: '/history', icon: '📋', label: 'History' },
  { key: '/activities', icon: '🧾', label: 'Activities' },
  { key: '/nft', icon: '🖼', label: 'NFT' },
  { key: '/approvals', icon: '🛡', label: 'Approvals' },
  { type: 'divider' as const },
  { key: '/dapp-search', icon: '🔍', label: 'DApps' },
  { key: '/gas-account', icon: '⛽', label: 'Gas Account' },
  { key: '/rabby-points', icon: '⭐', label: 'Points' },
  { type: 'divider' as const },
  { key: '/settings', icon: '⚙️', label: 'Settings' },
  { key: '/import', icon: '📥', label: 'Import' },
] as const;

const MOBILE_TABS = [
  { key: '/', icon: '🏠', label: 'Home' },
  { key: '/send-token', icon: '↑', label: 'Send' },
  { key: '/dex-swap', icon: '🔄', label: 'Swap' },
  { key: '/history', icon: '📋', label: 'History' },
  { key: 'more', icon: '⋯', label: 'More' },
] as const;

type NavItem = (typeof NAV_ITEMS)[number];

export default function MainLayout() {
  const navigate = useNavigate();
  const location = useLocation();
  const { connected, currentAccount, connect, disconnect } = useWallet();
  const { chains, currentChain, setCurrentChain } = useChainContext();
  const { effectiveTheme, setTheme } = useSettings();
  const [sideCollapsed, setSideCollapsed] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  const isActive = (key: string) => {
    if (key === '/') return location.pathname === '/';
    return location.pathname.startsWith(key);
  };

  const handleNav = (key: string) => {
    navigate(key);
    setMobileMenuOpen(false);
  };

  const handleSearchSubmit = () => {
    const q = searchQuery.trim();
    if (!q) return;
    setSearchQuery('');
    navigate('/dapp-search', { state: { q } });
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--r-neutral-bg-2, #f2f4f7)' }}>
      {/* TopBar */}
      <header style={{
        height: 'var(--rabby-topbar-height, 64px)',
        background: 'var(--r-neutral-bg-1, #fff)',
        borderBottom: '1px solid var(--r-neutral-line, #e0e5ec)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '0 24px',
        position: 'sticky',
        top: 0,
        zIndex: 100,
        boxShadow: 'var(--rabby-shadow-sm, 0 2px 4px rgba(0,0,0,0.04))',
      }}>
        {/* Left: Logo + Mobile menu */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
          <button
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            style={{
              display: 'none',
              background: 'none',
              border: 'none',
              fontSize: 20,
              cursor: 'pointer',
              color: 'var(--r-neutral-title-1, #192945)',
              padding: 4,
            }}
            className="mobile-menu-btn"
          >
            ☰
          </button>
          <Link to="/" style={{ display: 'flex', alignItems: 'center', gap: 8, textDecoration: 'none' }}>
            <div style={{
              width: 32, height: 32, borderRadius: 8,
              background: 'linear-gradient(135deg, var(--r-blue-default, #4c65ff), #7084ff)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: '#fff', fontWeight: 700, fontSize: 16,
            }}>
              R
            </div>
            <span style={{ fontWeight: 700, fontSize: 18, color: 'var(--r-neutral-title-1, #192945)' }}>Rabby</span>
          </Link>
        </div>

        {/* Center: Search */}
        <div style={{ flex: 1, padding: '0 24px' }} className="topbar-search">
          <div style={{ position: 'relative', maxWidth: 520, margin: '0 auto' }}>
            <span style={{
              position: 'absolute',
              left: 12,
              top: '50%',
              transform: 'translateY(-50%)',
              color: 'var(--r-neutral-foot, #6a7587)',
              fontSize: 14,
            }}>
              🔍
            </span>
            <input
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && handleSearchSubmit()}
              placeholder="Search dapps, tokens, or addresses..."
              style={{
                width: '100%',
                padding: '10px 12px 10px 32px',
                borderRadius: 10,
                border: '1px solid var(--r-neutral-line, #e0e5ec)',
                background: 'var(--r-neutral-card-1, #fff)',
                fontSize: 13,
                color: 'var(--r-neutral-title-1, #192945)',
              }}
            />
          </div>
        </div>

        {/* Right: Actions + Account */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <select
            value={currentChain?.id ?? ''}
            onChange={(e) => {
              const id = Number(e.target.value);
              const next = chains.find((c) => c.id === id);
              if (next) setCurrentChain(next);
            }}
            className="topbar-chain"
            style={{
              padding: '6px 10px',
              borderRadius: 8,
              border: '1px solid var(--r-neutral-line, #e0e5ec)',
              background: '#fff',
              fontSize: 12,
              color: 'var(--r-neutral-body, #3e495e)',
              minWidth: 120,
            }}
          >
            {!currentChain && <option value="">Loading...</option>}
            {chains.map((chain) => (
              <option key={chain.id} value={chain.id}>{chain.name}</option>
            ))}
          </select>
          <button
            style={{
              width: 32,
              height: 32,
              borderRadius: 8,
              border: '1px solid var(--r-neutral-line, #e0e5ec)',
              background: '#fff',
              cursor: 'pointer',
              fontSize: 14,
            }}
            title="Notifications"
          >
            🔔
          </button>
          <button
            onClick={() => setTheme(effectiveTheme === 'dark' ? 'light' : 'dark')}
            style={{
              width: 32,
              height: 32,
              borderRadius: 8,
              border: '1px solid var(--r-neutral-line, #e0e5ec)',
              background: '#fff',
              cursor: 'pointer',
              fontSize: 14,
            }}
            title="Toggle theme"
          >
            {effectiveTheme === 'dark' ? '☀️' : '🌙'}
          </button>
          {connected && currentAccount ? (
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <div style={{
                width: 28, height: 28, borderRadius: '50%',
                background: 'linear-gradient(135deg, #4c65ff, #7084ff)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                color: '#fff', fontSize: 12, fontWeight: 600,
              }}>
                {currentAccount.address.slice(2, 4).toUpperCase()}
              </div>
              <span style={{
                fontFamily: "'SF Mono', Menlo, monospace",
                fontSize: 13,
                color: 'var(--r-neutral-title-1, #192945)',
              }}>
                {currentAccount.address.slice(0, 6)}...{currentAccount.address.slice(-4)}
              </span>
              <button
                onClick={() => disconnect()}
                style={{
                  background: 'none', border: '1px solid var(--r-neutral-line, #e0e5ec)',
                  borderRadius: 6, padding: '4px 12px', cursor: 'pointer',
                  fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)',
                }}
              >
                Disconnect
              </button>
            </div>
          ) : (
            <button
              onClick={() => connect('demo')}
              style={{
                background: 'var(--r-blue-default, #4c65ff)',
                color: '#fff',
                border: 'none',
                borderRadius: 8,
                padding: '8px 20px',
                fontWeight: 600,
                fontSize: 14,
                cursor: 'pointer',
              }}
            >
              Connect Wallet
            </button>
          )}
        </div>
      </header>

      {/* Body */}
      <div style={{ display: 'flex', flex: 1, overflow: 'hidden' }}>
        {/* SideNav */}
        <nav style={{
          width: sideCollapsed
            ? 'var(--rabby-sidenav-collapsed-width, 64px)'
            : 'var(--rabby-sidenav-width, 240px)',
          background: 'var(--r-neutral-bg-1, #fff)',
          borderRight: '1px solid var(--r-neutral-line, #e0e5ec)',
          overflow: 'auto',
          transition: 'width 200ms ease-in-out',
          flexShrink: 0,
          display: 'flex',
          flexDirection: 'column',
        }} className="side-nav">
          <div style={{ flex: 1, padding: '12px 8px' }}>
            {NAV_ITEMS.map((item, i) => {
              if ('type' in item && item.type === 'divider') {
                return <div key={`d-${i}`} style={{ height: 1, background: 'var(--r-neutral-line, #e0e5ec)', margin: '8px 12px' }} />;
              }
              const navItem = item as { key: string; icon: string; label: string };
              const active = isActive(navItem.key);
              return (
                <button
                  key={navItem.key}
                  onClick={() => handleNav(navItem.key)}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 12,
                    width: '100%',
                    padding: sideCollapsed ? '10px 0' : '10px 16px',
                    justifyContent: sideCollapsed ? 'center' : 'flex-start',
                    background: active ? 'var(--r-blue-light-1, #edf0ff)' : 'transparent',
                    color: active ? 'var(--r-blue-default, #4c65ff)' : 'var(--r-neutral-body, #3e495e)',
                    border: 'none',
                    borderRadius: 8,
                    cursor: 'pointer',
                    fontSize: 14,
                    fontWeight: active ? 600 : 400,
                    marginBottom: 2,
                    transition: 'all 150ms ease-in-out',
                  }}
                >
                  <span style={{ fontSize: 18, width: 24, textAlign: 'center' }}>{navItem.icon}</span>
                  {!sideCollapsed && <span>{navItem.label}</span>}
                </button>
              );
            })}
          </div>

          {/* Collapse toggle */}
          <button
            onClick={() => setSideCollapsed(!sideCollapsed)}
            style={{
              padding: 12,
              background: 'none',
              border: 'none',
              borderTop: '1px solid var(--r-neutral-line, #e0e5ec)',
              cursor: 'pointer',
              color: 'var(--r-neutral-foot, #6a7587)',
              fontSize: 16,
            }}
          >
            {sideCollapsed ? '→' : '←'}
          </button>
        </nav>

        {/* Mobile overlay */}
        {mobileMenuOpen && (
          <div
            style={{
              position: 'fixed',
              top: 'var(--rabby-topbar-height, 64px)',
              left: 0,
              right: 0,
              bottom: 0,
              background: 'rgba(0,0,0,0.3)', zIndex: 50,
            }}
            onClick={() => setMobileMenuOpen(false)}
            className="mobile-overlay"
          />
        )}

        {/* Main content */}
        <main
          className="main-content"
          style={{
            flex: 1,
            overflow: 'auto',
            padding: 24,
          }}
        >
          <div style={{ maxWidth: 'var(--rabby-content-max-width, 800px)', margin: '0 auto' }}>
            <Outlet />
          </div>
        </main>
      </div>

      {/* Mobile bottom tabbar */}
      <div
        className="mobile-tabbar"
        style={{
          position: 'fixed',
          left: 0,
          right: 0,
          bottom: 0,
          height: 'var(--rabby-bottom-tab-height, 56px)',
          background: 'var(--r-neutral-bg-1, #fff)',
          borderTop: '1px solid var(--r-neutral-line, #e0e5ec)',
          display: 'none',
          alignItems: 'center',
          justifyContent: 'space-around',
          zIndex: 60,
        }}
      >
        {MOBILE_TABS.map((tab) => {
          const isMore = tab.key === 'more';
          const active = isMore ? mobileMenuOpen : isActive(tab.key);
          return (
            <button
              key={tab.key}
              onClick={() => {
                if (isMore) {
                  setMobileMenuOpen(true);
                  return;
                }
                handleNav(tab.key);
              }}
              style={{
                background: 'none',
                border: 'none',
                cursor: 'pointer',
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                gap: 4,
                color: active
                  ? 'var(--r-blue-default, #4c65ff)'
                  : 'var(--r-neutral-foot, #6a7587)',
                fontSize: 10,
              }}
            >
              <span style={{ fontSize: 16 }}>{tab.icon}</span>
              <span>{tab.label}</span>
            </button>
          );
        })}
      </div>

      {/* Mobile bottom tab - add responsive CSS class */}
      <style>{`
        @media (max-width: 768px) {
          .side-nav { display: none !important; }
          .mobile-menu-btn { display: block !important; }
          .topbar-search { display: none !important; }
          .topbar-chain { display: none !important; }
          .main-content { padding-bottom: calc(var(--rabby-bottom-tab-height, 56px) + 16px); }
          .mobile-tabbar { display: flex !important; }
        }
        @media (min-width: 769px) {
          .mobile-overlay { display: none !important; }
          .mobile-menu-btn { display: none !important; }
          .mobile-tabbar { display: none !important; }
        }
      `}</style>
    </div>
  );
}
