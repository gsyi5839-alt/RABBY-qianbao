import React, { useState, useMemo, useCallback } from 'react';
import type { TokenApproval } from '@rabby/shared';
import { useWallet } from '../../contexts/WalletContext';

/* ─── Mock Data ─── */

const MOCK_APPROVALS: TokenApproval[] = [
  {
    id: 'ap-1',
    token: { id: '0xa0b8-usdc', chain: 'eth', name: 'USD Coin', symbol: 'USDC', decimals: 6, logo_url: '', price: 1.0, amount: 5240.00 },
    spender: { id: '0x68b3465833fb72a70ecdf485e0e4c7bd8665fc45', name: 'Uniswap V3 Router', protocol_id: 'uniswap3', is_contract: true, risk_level: 'safe' },
    amount: 115792089237316195423570985008687907853269984665640564039457584007913129639935,
    is_unlimited: true,
  },
  {
    id: 'ap-2',
    token: { id: '0xdac1-usdt', chain: 'eth', name: 'Tether', symbol: 'USDT', decimals: 6, logo_url: '', price: 1.0, amount: 3100.00 },
    spender: { id: '0xdef1c0ded9bec7f1a1670819833240f027b25eff', name: '0x Exchange Proxy', protocol_id: '0x', is_contract: true, risk_level: 'safe' },
    amount: 115792089237316195423570985008687907853269984665640564039457584007913129639935,
    is_unlimited: true,
  },
  {
    id: 'ap-3',
    token: { id: '0x6b17-dai', chain: 'eth', name: 'Dai', symbol: 'DAI', decimals: 18, logo_url: '', price: 1.0, amount: 1890.00 },
    spender: { id: '0xd9e1ce17f2641f24ae83637ab66a2cca9c378b9f', name: 'SushiSwap Router', protocol_id: 'sushi', is_contract: true, risk_level: 'warning' },
    amount: 50000,
    is_unlimited: false,
  },
  {
    id: 'ap-4',
    token: { id: '0x2260-wbtc', chain: 'eth', name: 'Wrapped BTC', symbol: 'WBTC', decimals: 8, logo_url: '', price: 97250.00, amount: 0.085 },
    spender: { id: '0x3ee18b2214aff97000d974cf647e7c347e8fa585', name: 'Unknown Contract', is_contract: true, risk_level: 'danger' },
    amount: 115792089237316195423570985008687907853269984665640564039457584007913129639935,
    is_unlimited: true,
  },
  {
    id: 'ap-5',
    token: { id: '0x514910-link', chain: 'eth', name: 'Chainlink', symbol: 'LINK', decimals: 18, logo_url: '', price: 18.42, amount: 320.5 },
    spender: { id: '0x7a250d5630b4cf539739df2c5dacb4c659f2488d', name: 'Uniswap V2 Router', protocol_id: 'uniswap2', is_contract: true, risk_level: 'safe' },
    amount: 115792089237316195423570985008687907853269984665640564039457584007913129639935,
    is_unlimited: true,
  },
  {
    id: 'ap-6',
    token: { id: '0x1f9840-uni', chain: 'eth', name: 'Uniswap', symbol: 'UNI', decimals: 18, logo_url: '', price: 12.85, amount: 150.0 },
    spender: { id: '0xe592427a0aece92de3edee1f18e0157c05861564', name: 'Uniswap V3 Router', protocol_id: 'uniswap3', is_contract: true, risk_level: 'safe' },
    amount: 5000,
    is_unlimited: false,
  },
  {
    id: 'ap-7',
    token: { id: '0xa0b8-usdc-2', chain: 'eth', name: 'USD Coin', symbol: 'USDC', decimals: 6, logo_url: '', price: 1.0, amount: 5240.00 },
    spender: { id: '0x1111111254eeb25477b68fb85ed929f73a960582', name: '1inch Router', protocol_id: '1inch', is_contract: true, risk_level: 'warning' },
    amount: 10000,
    is_unlimited: false,
  },
  {
    id: 'ap-8',
    token: { id: '0x95ad-shib', chain: 'eth', name: 'Shiba Inu', symbol: 'SHIB', decimals: 18, logo_url: '', price: 0.0000234, amount: 45000000 },
    spender: { id: '0xabcdef1234567890abcdef1234567890abcdef12', name: 'Unverified Spender', is_contract: true, risk_level: 'danger' },
    amount: 115792089237316195423570985008687907853269984665640564039457584007913129639935,
    is_unlimited: true,
  },
];

/* ─── Helpers ─── */

function formatUsd(value: number): string {
  if (value >= 1_000_000) return `$${(value / 1_000_000).toFixed(2)}M`;
  if (value >= 1_000) return `$${(value / 1_000).toFixed(2)}K`;
  return value.toLocaleString('en-US', { style: 'currency', currency: 'USD' });
}

function formatAmount(value: number): string {
  if (value >= 1_000_000_000) return `${(value / 1_000_000_000).toFixed(1)}B`;
  if (value >= 1_000_000) return `${(value / 1_000_000).toFixed(1)}M`;
  if (value >= 1_000) return `${(value / 1_000).toFixed(1)}K`;
  return value.toLocaleString('en-US', { maximumFractionDigits: 4 });
}

function truncateAddress(addr: string): string {
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

function getUsdAtRisk(approval: TokenApproval): number {
  if (approval.is_unlimited) {
    return approval.token.amount * approval.token.price;
  }
  const approvedValue = approval.amount * approval.token.price;
  const balanceValue = approval.token.amount * approval.token.price;
  return Math.min(approvedValue, balanceValue);
}

function getRiskLevel(approval: TokenApproval): 'safe' | 'warning' | 'danger' {
  if (approval.spender.risk_level) return approval.spender.risk_level;
  if (approval.is_unlimited) return 'warning';
  const usdAtRisk = getUsdAtRisk(approval);
  if (usdAtRisk > 10000) return 'warning';
  return 'safe';
}

type TabFilter = 'all' | 'unlimited' | 'risky';
type ApprovalVariant = 'all' | 'token' | 'nft';

/* ─── Inline sub-components ─── */

function TokenIcon({ token, size = 32 }: { token: TokenApproval['token']; size?: number }) {
  if (token.logo_url) {
    return (
      <img
        src={token.logo_url}
        alt={token.symbol}
        style={{ width: size, height: size, borderRadius: '50%' }}
        onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
      />
    );
  }
  return (
    <div style={{
      width: size, height: size, borderRadius: '50%',
      background: 'var(--r-blue-light-1, #edf0ff)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontSize: size * 0.4, fontWeight: 700,
      color: 'var(--r-blue-default, #4c65ff)',
    }}>
      {token.symbol?.[0] ?? '?'}
    </div>
  );
}

function RiskBadge({ level }: { level: 'safe' | 'warning' | 'danger' }) {
  const config = {
    safe: {
      bg: 'var(--r-green-light, #e8faf2)',
      color: 'var(--r-green-default, #27c193)',
      label: 'Safe',
    },
    warning: {
      bg: 'var(--r-orange-light, #fff5e0)',
      color: 'var(--r-orange-default, #ffb020)',
      label: 'Warning',
    },
    danger: {
      bg: 'var(--r-red-light, #ffeded)',
      color: 'var(--r-red-default, #ec5151)',
      label: 'Danger',
    },
  }[level];

  return (
    <span style={{
      display: 'inline-block',
      padding: '2px 8px', borderRadius: 4,
      background: config.bg, color: config.color,
      fontSize: 11, fontWeight: 700,
      lineHeight: '16px',
    }}>
      {config.label}
    </span>
  );
}

/* ─── Main Approvals Page ─── */

export default function ApprovalsPage({ variant = 'all' }: { variant?: ApprovalVariant }) {
  const { currentAccount } = useWallet();
  const pageTitle = variant === 'nft' ? 'NFT Approvals' : variant === 'token' ? 'Token Approvals' : 'Approvals';
  const approvalsSource = variant === 'nft' ? [] : MOCK_APPROVALS;

  const [activeTab, setActiveTab] = useState<TabFilter>('all');
  const [revoking, setRevoking] = useState<Record<string, boolean>>({});
  const [revokeConfirm, setRevokeConfirm] = useState<string | null>(null);
  const [revoked, setRevoked] = useState<Set<string>>(new Set());

  /* Filtered approvals */
  const approvals = useMemo(() => {
    const active = approvalsSource.filter((a) => !revoked.has(a.id));
    switch (activeTab) {
      case 'unlimited':
        return active.filter((a) => a.is_unlimited);
      case 'risky':
        return active.filter((a) => getRiskLevel(a) !== 'safe');
      default:
        return active;
    }
  }, [activeTab, approvalsSource, revoked]);

  /* Summary stats */
  const summary = useMemo(() => {
    const active = approvalsSource.filter((a) => !revoked.has(a.id));
    const totalUsd = active.reduce((sum, a) => sum + getUsdAtRisk(a), 0);
    const riskyCount = active.filter((a) => getRiskLevel(a) !== 'safe').length;
    const unlimitedCount = active.filter((a) => a.is_unlimited).length;
    return { totalUsd, riskyCount, unlimitedCount, totalCount: active.length };
  }, [approvalsSource, revoked]);

  /* Handlers */
  const handleRevoke = useCallback(async (id: string) => {
    setRevoking((prev) => ({ ...prev, [id]: true }));
    try {
      // Simulate revoke transaction
      await new Promise((r) => setTimeout(r, 1500));
      setRevoked((prev) => new Set(prev).add(id));
      setRevokeConfirm(null);
    } catch {
      // error handled
    } finally {
      setRevoking((prev) => ({ ...prev, [id]: false }));
    }
  }, []);

  /* ─── Styles ─── */
  const cardStyle: React.CSSProperties = {
    background: 'var(--r-neutral-card-1, #fff)',
    borderRadius: 16,
    boxShadow: 'var(--rabby-shadow-sm, 0 2px 4px rgba(0,0,0,0.04))',
  };

  const tabs: { key: TabFilter; label: string; count?: number }[] = [
    { key: 'all', label: 'All', count: summary.totalCount },
    { key: 'unlimited', label: 'Unlimited', count: summary.unlimitedCount },
    { key: 'risky', label: 'Risky', count: summary.riskyCount },
  ];

  /* ─── Revoke Confirmation Modal ─── */
  const renderRevokeConfirm = () => {
    if (!revokeConfirm) return null;
    const approval = approvalsSource.find((a) => a.id === revokeConfirm);
    if (!approval) return null;
    const isRevoking = revoking[revokeConfirm] || false;

    return (
      <div style={{
        position: 'fixed', inset: 0, zIndex: 1000,
        background: 'rgba(0,0,0,0.4)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}
        onClick={() => !isRevoking && setRevokeConfirm(null)}
      >
        <div
          style={{
            background: 'var(--r-neutral-card-1, #fff)',
            borderRadius: 20, width: 400, padding: 24,
            boxShadow: '0 20px 60px rgba(0,0,0,0.15)',
          }}
          onClick={(e) => e.stopPropagation()}
        >
          <div style={{ fontWeight: 600, fontSize: 18, color: 'var(--r-neutral-title-1, #192945)', marginBottom: 8, textAlign: 'center' }}>
            Revoke Approval
          </div>
          <div style={{ fontSize: 14, color: 'var(--r-neutral-foot, #6a7587)', marginBottom: 20, textAlign: 'center' }}>
            Are you sure you want to revoke the {approval.token.symbol} approval for{' '}
            <span style={{ fontWeight: 600, color: 'var(--r-neutral-title-1, #192945)' }}>
              {approval.spender.name || truncateAddress(approval.spender.id)}
            </span>?
          </div>

          {/* Details */}
          <div style={{
            background: 'var(--r-neutral-bg-2, #f2f4f7)', borderRadius: 12,
            padding: '12px 16px', marginBottom: 20,
          }}>
            {[
              { label: 'Token', value: approval.token.symbol },
              { label: 'Spender', value: approval.spender.name || truncateAddress(approval.spender.id) },
              { label: 'Approved Amount', value: approval.is_unlimited ? 'Unlimited' : formatAmount(approval.amount) },
              { label: 'Value at Risk', value: formatUsd(getUsdAtRisk(approval)) },
            ].map((row) => (
              <div key={row.label} style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0' }}>
                <span style={{ fontSize: 13, color: 'var(--r-neutral-foot, #6a7587)' }}>{row.label}</span>
                <span style={{ fontSize: 13, fontWeight: 500, color: 'var(--r-neutral-title-1, #192945)' }}>{row.value}</span>
              </div>
            ))}
          </div>

          {/* Buttons */}
          <div style={{ display: 'flex', gap: 12 }}>
            <button
              onClick={() => setRevokeConfirm(null)}
              disabled={isRevoking}
              style={{
                flex: 1, padding: '14px 0', borderRadius: 12,
                border: '1px solid var(--r-neutral-line, #e0e5ec)',
                background: 'transparent', fontSize: 15, fontWeight: 600,
                cursor: isRevoking ? 'not-allowed' : 'pointer',
                color: 'var(--r-neutral-title-1, #192945)',
              }}
            >
              Cancel
            </button>
            <button
              onClick={() => handleRevoke(revokeConfirm)}
              disabled={isRevoking}
              style={{
                flex: 1, padding: '14px 0', borderRadius: 12,
                border: 'none',
                background: isRevoking
                  ? 'var(--r-neutral-foot, #6a7587)'
                  : 'var(--r-red-default, #ec5151)',
                fontSize: 15, fontWeight: 600,
                cursor: isRevoking ? 'not-allowed' : 'pointer',
                color: '#fff',
              }}
            >
              {isRevoking ? 'Revoking...' : 'Revoke'}
            </button>
          </div>
        </div>
      </div>
    );
  };

  /* ─── Render ─── */
  return (
    <div style={{ maxWidth: 640, margin: '0 auto' }}>
      <h2 style={{
        fontSize: 20, fontWeight: 600, margin: '0 0 24px',
        color: 'var(--r-neutral-title-1, #192945)',
      }}>
        {pageTitle}
      </h2>

      {/* ─── Summary Card ─── */}
      <div style={{
        ...cardStyle,
        padding: '20px 24px', marginBottom: 16,
        background: 'linear-gradient(135deg, var(--r-blue-default, #4c65ff), var(--r-blue-default, #4c65ff) 60%, #7b8dff)',
        color: '#fff',
      }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <div>
            <div style={{ fontSize: 12, opacity: 0.8, marginBottom: 4 }}>Total Approved Value at Risk</div>
            <div style={{ fontSize: 28, fontWeight: 700, letterSpacing: '-0.5px' }}>
              {formatUsd(summary.totalUsd)}
            </div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div style={{
              fontSize: 12, opacity: 0.8, marginBottom: 4,
            }}>
              {summary.totalCount} approval{summary.totalCount !== 1 ? 's' : ''}
            </div>
            {summary.riskyCount > 0 && (
              <div style={{
                display: 'inline-block',
                padding: '4px 10px', borderRadius: 8,
                background: 'rgba(255,255,255,0.2)',
                fontSize: 13, fontWeight: 600,
              }}>
                {summary.riskyCount} risky
              </div>
            )}
          </div>
        </div>

        {/* Mini stat row */}
        <div style={{ display: 'flex', gap: 16, marginTop: 16 }}>
          <div style={{
            flex: 1, padding: '10px 14px', borderRadius: 10,
            background: 'rgba(255,255,255,0.15)',
          }}>
            <div style={{ fontSize: 11, opacity: 0.75, marginBottom: 2 }}>Unlimited</div>
            <div style={{ fontSize: 16, fontWeight: 700 }}>{summary.unlimitedCount}</div>
          </div>
          <div style={{
            flex: 1, padding: '10px 14px', borderRadius: 10,
            background: 'rgba(255,255,255,0.15)',
          }}>
            <div style={{ fontSize: 11, opacity: 0.75, marginBottom: 2 }}>Risky</div>
            <div style={{ fontSize: 16, fontWeight: 700 }}>{summary.riskyCount}</div>
          </div>
          <div style={{
            flex: 1, padding: '10px 14px', borderRadius: 10,
            background: 'rgba(255,255,255,0.15)',
          }}>
            <div style={{ fontSize: 11, opacity: 0.75, marginBottom: 2 }}>Safe</div>
            <div style={{ fontSize: 16, fontWeight: 700 }}>{summary.totalCount - summary.riskyCount}</div>
          </div>
        </div>
      </div>

      {/* ─── Tab Filter ─── */}
      <div style={{
        display: 'flex', gap: 4,
        background: 'var(--r-neutral-bg-2, #f2f4f7)',
        padding: 4, borderRadius: 12, marginBottom: 16,
      }}>
        {tabs.map((tab) => (
          <button
            key={tab.key}
            onClick={() => setActiveTab(tab.key)}
            style={{
              flex: 1, padding: '8px 0', borderRadius: 8,
              border: 'none', cursor: 'pointer',
              background: activeTab === tab.key
                ? 'var(--r-neutral-card-1, #fff)'
                : 'transparent',
              boxShadow: activeTab === tab.key
                ? 'var(--rabby-shadow-sm, 0 2px 4px rgba(0,0,0,0.04))'
                : 'none',
              color: activeTab === tab.key
                ? 'var(--r-neutral-title-1, #192945)'
                : 'var(--r-neutral-foot, #6a7587)',
              fontSize: 13, fontWeight: 600,
              transition: 'background 150ms, box-shadow 150ms, color 150ms',
            }}
          >
            {tab.label}
            {tab.count != null && (
              <span style={{
                marginLeft: 4, fontSize: 11,
                opacity: activeTab === tab.key ? 1 : 0.6,
              }}>
                ({tab.count})
              </span>
            )}
          </button>
        ))}
      </div>

      {/* ─── Approvals List ─── */}
      {approvals.length === 0 ? (
        <div style={{
          ...cardStyle,
          padding: '48px 24px', textAlign: 'center',
        }}>
          <div style={{ fontSize: 40, marginBottom: 12, opacity: 0.3 }}>&#10003;</div>
          <div style={{ fontSize: 16, fontWeight: 600, color: 'var(--r-neutral-title-1, #192945)', marginBottom: 4 }}>
            No approvals found
          </div>
          <div style={{ fontSize: 13, color: 'var(--r-neutral-foot, #6a7587)' }}>
            {activeTab === 'all'
              ? `You have no ${variant === 'nft' ? 'NFT' : 'token'} approvals`
              : `No ${activeTab} approvals to show`}
          </div>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {approvals.map((approval) => {
            const risk = getRiskLevel(approval);
            const usdAtRisk = getUsdAtRisk(approval);
            const isRevoking = revoking[approval.id] || false;

            return (
              <div key={approval.id} style={{
                ...cardStyle,
                padding: '16px 20px',
                transition: 'box-shadow 200ms',
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  {/* Token icon + info */}
                  <TokenIcon token={approval.token} size={40} />

                  <div style={{ flex: 1, minWidth: 0 }}>
                    {/* Row 1: Token + Risk badge */}
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                      <span style={{
                        fontWeight: 600, fontSize: 15,
                        color: 'var(--r-neutral-title-1, #192945)',
                      }}>
                        {approval.token.symbol}
                      </span>
                      <RiskBadge level={risk} />
                    </div>

                    {/* Row 2: Spender info */}
                    <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                      {approval.spender.logo_url && (
                        <img
                          src={approval.spender.logo_url}
                          alt=""
                          style={{ width: 14, height: 14, borderRadius: 3 }}
                        />
                      )}
                      <span style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)' }}>
                        {approval.spender.name || 'Unknown'}
                      </span>
                      <span style={{
                        fontSize: 11, color: 'var(--r-neutral-foot, #6a7587)', opacity: 0.7,
                      }}>
                        {truncateAddress(approval.spender.id)}
                      </span>
                    </div>
                  </div>

                  {/* Right side: Amount + Revoke */}
                  <div style={{ textAlign: 'right', flexShrink: 0 }}>
                    <div style={{
                      fontSize: 13, fontWeight: 600,
                      color: approval.is_unlimited
                        ? 'var(--r-orange-default, #ffb020)'
                        : 'var(--r-neutral-title-1, #192945)',
                      marginBottom: 2,
                    }}>
                      {approval.is_unlimited ? 'Unlimited' : formatAmount(approval.amount)}
                    </div>
                    <div style={{
                      fontSize: 12,
                      color: risk === 'danger'
                        ? 'var(--r-red-default, #ec5151)'
                        : 'var(--r-neutral-foot, #6a7587)',
                      marginBottom: 8,
                    }}>
                      {formatUsd(usdAtRisk)} at risk
                    </div>
                    <button
                      onClick={() => setRevokeConfirm(approval.id)}
                      disabled={isRevoking}
                      style={{
                        padding: '6px 16px', borderRadius: 8,
                        border: risk === 'danger'
                          ? '1px solid var(--r-red-default, #ec5151)'
                          : '1px solid var(--r-neutral-line, #e0e5ec)',
                        background: risk === 'danger'
                          ? 'var(--r-red-light, #ffeded)'
                          : 'transparent',
                        color: risk === 'danger'
                          ? 'var(--r-red-default, #ec5151)'
                          : 'var(--r-neutral-title-1, #192945)',
                        fontSize: 12, fontWeight: 600,
                        cursor: isRevoking ? 'not-allowed' : 'pointer',
                        transition: 'background 150ms',
                      }}
                    >
                      {isRevoking ? 'Revoking...' : 'Revoke'}
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Revoke confirm modal */}
      {renderRevokeConfirm()}
    </div>
  );
}
