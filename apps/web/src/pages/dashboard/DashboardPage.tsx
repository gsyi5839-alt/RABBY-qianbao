import React, { useCallback, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useCurrentBalance } from '../../hooks';
import { usePreference } from '../../hooks';
import { formatUsdValue } from '../../utils';
import { AccountHeader } from './components/AccountHeader';
import { TokenListPanel } from './components/TokenListPanel';
import { ChainBalanceBar } from './components/ChainBalanceBar';
import { GasPriceBar } from './components/GasPriceBar';

/**
 * DashboardPage -- main wallet dashboard.
 *
 * Displays account header, total balance, quick action grid,
 * chain balance bar, token list with sort/filter, and gas price bar.
 */

interface QuickAction {
  label: string;
  icon: string;
  path: string;
}

const quickActions: QuickAction[] = [
  { label: 'Send', icon: 'M12 19l9 2-9-18-9 18 9-2zm0 0v-8', path: '/send-token' },
  { label: 'Receive', icon: 'M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4', path: '/receive' },
  { label: 'Swap', icon: 'M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4', path: '/dex-swap' },
  { label: 'Bridge', icon: 'M13 10V3L4 14h7v7l9-11h-7z', path: '/bridge' },
  { label: 'NFT', icon: 'M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z', path: '/nft' },
  { label: 'History', icon: 'M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z', path: '/history' },
];

const styles = {
  page: {
    minHeight: '100vh',
    background: 'var(--r-neutral-bg-2)',
    display: 'flex',
    flexDirection: 'column',
  } as React.CSSProperties,
  header: {
    background: 'linear-gradient(135deg, #4c65ff 0%, #3a52e0 100%)',
    padding: '48px 20px 24px',
  } as React.CSSProperties,
  balanceArea: {
    textAlign: 'center',
    marginTop: 24,
  } as React.CSSProperties,
  balanceLabel: {
    fontSize: 13,
    color: 'rgba(255,255,255,0.6)',
    marginBottom: 4,
  } as React.CSSProperties,
  balanceRow: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: '8px',
  } as React.CSSProperties,
  balanceValue: {
    fontSize: 36,
    fontWeight: 700,
    color: '#fff',
    lineHeight: '44px',
  } as React.CSSProperties,
  hiddenBalance: {
    fontSize: 36,
    fontWeight: 700,
    color: '#fff',
    lineHeight: '44px',
    letterSpacing: 4,
  } as React.CSSProperties,
  eyeBtn: {
    border: 'none',
    background: 'transparent',
    cursor: 'pointer',
    padding: 4,
    display: 'flex',
    alignItems: 'center',
  } as React.CSSProperties,
  actionsCard: {
    margin: '-14px 20px 0',
    background: 'var(--r-neutral-card-1)',
    borderRadius: 16,
    boxShadow: 'var(--rabby-shadow-md)',
    padding: '16px',
    position: 'relative',
    zIndex: 2,
  } as React.CSSProperties,
  actionsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(3, 1fr)',
    gap: '8px',
  } as React.CSSProperties,
  actionBtn: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    gap: '8px',
    padding: '12px 4px',
    borderRadius: 12,
    border: 'none',
    background: 'transparent',
    cursor: 'pointer',
    transition: 'background 0.15s',
  } as React.CSSProperties,
  actionIcon: {
    width: 44,
    height: 44,
    borderRadius: '50%',
    background: 'var(--r-blue-light-1)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
  } as React.CSSProperties,
  actionLabel: {
    fontSize: 12,
    fontWeight: 500,
    color: 'var(--r-neutral-body)',
  } as React.CSSProperties,
  body: {
    flex: 1,
    padding: '16px 20px',
    display: 'flex',
    flexDirection: 'column',
    gap: '16px',
  } as React.CSSProperties,
  footer: {
    padding: '0 20px 24px',
  } as React.CSSProperties,
  refreshIndicator: {
    textAlign: 'center',
    padding: '12px 0',
    fontSize: 12,
    color: 'var(--r-neutral-foot)',
  } as React.CSSProperties,
};

const DashboardPage: React.FC = () => {
  const navigate = useNavigate();
  const {
    balance,
    balanceLoading,
    refreshBalance,
  } = useCurrentBalance();
  const { hiddenBalance, setHiddenBalance } = usePreference();

  const [chainFilter, setChainFilter] = useState<string>('');
  const [isRefreshing, setIsRefreshing] = useState(false);

  const handleRefresh = useCallback(async () => {
    if (isRefreshing) return;
    setIsRefreshing(true);
    try {
      await refreshBalance();
    } finally {
      setIsRefreshing(false);
    }
  }, [isRefreshing, refreshBalance]);

  const handleChainFilter = useCallback((chainId: string) => {
    setChainFilter((prev) => (prev === chainId ? '' : chainId));
  }, []);

  const toggleHideBalance = useCallback(() => {
    setHiddenBalance(!hiddenBalance);
  }, [hiddenBalance, setHiddenBalance]);

  return (
    <div style={styles.page}>
      {/* Pull-to-refresh indicator */}
      {isRefreshing && (
        <div style={styles.refreshIndicator}>Refreshing...</div>
      )}

      {/* Header with account info + balance */}
      <header style={styles.header}>
        <AccountHeader />

        <div style={styles.balanceArea} onClick={handleRefresh} role="button" tabIndex={0}>
          <p style={styles.balanceLabel}>
            {isRefreshing ? 'Refreshing...' : 'Total Balance'}
          </p>
          <div style={styles.balanceRow}>
            {hiddenBalance ? (
              <span style={styles.hiddenBalance}>****</span>
            ) : (
              <span style={styles.balanceValue}>
                {balanceLoading ? '...' : formatUsdValue(balance)}
              </span>
            )}
            <button style={styles.eyeBtn} onClick={toggleHideBalance}>
              {hiddenBalance ? (
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.5)" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
                  <path d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19m-6.72-1.07a3 3 0 11-4.24-4.24" />
                  <line x1="1" y1="1" x2="23" y2="23" />
                </svg>
              ) : (
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.5)" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
                  <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                  <circle cx="12" cy="12" r="3" />
                </svg>
              )}
            </button>
          </div>
        </div>
      </header>

      {/* Quick action buttons */}
      <div style={styles.actionsCard}>
        <div style={styles.actionsGrid}>
          {quickActions.map((action) => (
            <button
              key={action.label}
              style={styles.actionBtn}
              onClick={() => navigate(action.path)}
            >
              <div style={styles.actionIcon}>
                <svg
                  width="20"
                  height="20"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="var(--rabby-brand)"
                  strokeWidth={2}
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <path d={action.icon} />
                </svg>
              </div>
              <span style={styles.actionLabel}>{action.label}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Main content */}
      <div style={styles.body}>
        {/* Chain balance bar */}
        <ChainBalanceBar
          activeChain={chainFilter}
          onChainClick={handleChainFilter}
        />

        {/* Token list */}
        <TokenListPanel chainFilter={chainFilter || undefined} />
      </div>

      {/* Gas price footer */}
      <footer style={styles.footer}>
        <GasPriceBar />
      </footer>
    </div>
  );
};

export default DashboardPage;
