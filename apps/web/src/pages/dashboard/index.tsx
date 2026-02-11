import React, { useState, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { useWallet } from '../../contexts/WalletContext';
import { useTokenList } from '../../hooks/useTokenList';
import { useChainContext } from '../../contexts/ChainContext';

type TabKey = 'tokens' | 'nft' | 'defi' | 'activity';

export default function Dashboard() {
  const navigate = useNavigate();
  const { connected, currentAccount } = useWallet();
  const { currentChain } = useChainContext();
  const { tokens, loading } = useTokenList(currentChain?.serverId);
  const [activeTab, setActiveTab] = useState<TabKey>('tokens');

  const totalBalance = useMemo(() => {
    return tokens.reduce((sum, t) => sum + t.amount * t.price, 0);
  }, [tokens]);

  if (!connected || !currentAccount) {
    return (
      <div style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        minHeight: 400,
        gap: 24,
      }}>
        <div style={{
          width: 80, height: 80, borderRadius: 20,
          background: 'linear-gradient(135deg, var(--r-blue-default, #4c65ff), #7084ff)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: 36, color: '#fff',
        }}>
          R
        </div>
        <h2 style={{ margin: 0, color: 'var(--r-neutral-title-1, #192945)', fontSize: 24 }}>
          Welcome to Rabby
        </h2>
        <p style={{ margin: 0, color: 'var(--r-neutral-foot, #6a7587)', fontSize: 14 }}>
          Connect your wallet to get started
        </p>
      </div>
    );
  }

  const tabs: { key: TabKey; label: string }[] = [
    { key: 'tokens', label: 'Tokens' },
    { key: 'nft', label: 'NFT' },
    { key: 'defi', label: 'DeFi' },
    { key: 'activity', label: 'Activity' },
  ];

  return (
    <div>
      {/* Asset Overview Card */}
      <div style={{
        background: 'linear-gradient(135deg, var(--r-blue-default, #4c65ff) 0%, #7084ff 50%, #8b9cff 100%)',
        borderRadius: 16,
        padding: '32px 28px',
        color: '#fff',
        marginBottom: 24,
      }}>
        <div style={{ fontSize: 13, opacity: 0.8, marginBottom: 8 }}>Total Balance</div>
        <div style={{ fontSize: 32, fontWeight: 700, marginBottom: 4 }}>
          ${totalBalance.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
        </div>
        <div style={{ fontSize: 13, opacity: 0.7 }}>
          {currentAccount.address.slice(0, 6)}...{currentAccount.address.slice(-4)}
        </div>

        {/* Quick Actions */}
        <div style={{ display: 'flex', gap: 12, marginTop: 24 }}>
          {[
            { label: 'Send', icon: '↑', path: '/send-token' },
            { label: 'Receive', icon: '↓', path: '/receive' },
            { label: 'Swap', icon: '🔄', path: '/dex-swap' },
            { label: 'Bridge', icon: '🌉', path: '/bridge' },
          ].map((action) => (
            <button
              key={action.label}
              onClick={() => navigate(action.path)}
              style={{
                flex: 1,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                gap: 6,
                padding: '12px 0',
                background: 'rgba(255,255,255,0.15)',
                border: '1px solid rgba(255,255,255,0.2)',
                borderRadius: 12,
                color: '#fff',
                cursor: 'pointer',
                fontSize: 12,
                backdropFilter: 'blur(10px)',
              }}
            >
              <span style={{ fontSize: 20 }}>{action.icon}</span>
              <span>{action.label}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Tabs */}
      <div style={{
        display: 'flex',
        gap: 0,
        borderBottom: '1px solid var(--r-neutral-line, #e0e5ec)',
        marginBottom: 16,
      }}>
        {tabs.map((tab) => (
          <button
            key={tab.key}
            onClick={() => setActiveTab(tab.key)}
            style={{
              flex: 1,
              padding: '12px 0',
              background: 'none',
              border: 'none',
              borderBottom: activeTab === tab.key ? '2px solid var(--r-blue-default, #4c65ff)' : '2px solid transparent',
              color: activeTab === tab.key ? 'var(--r-blue-default, #4c65ff)' : 'var(--r-neutral-foot, #6a7587)',
              fontWeight: activeTab === tab.key ? 600 : 400,
              fontSize: 14,
              cursor: 'pointer',
              transition: 'all 150ms ease-in-out',
            }}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Token List */}
      {activeTab === 'tokens' && (
        <div>
          {loading ? (
            <div style={{ textAlign: 'center', padding: 40, color: 'var(--r-neutral-foot, #6a7587)' }}>
              Loading tokens...
            </div>
          ) : tokens.length === 0 ? (
            <div style={{ textAlign: 'center', padding: 40, color: 'var(--r-neutral-foot, #6a7587)' }}>
              No tokens found
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
              {tokens.map((token) => {
                const usdValue = token.amount * token.price;
                return (
                  <div
                    key={token.id}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      padding: '14px 16px',
                      background: 'var(--r-neutral-card-1, #fff)',
                      borderRadius: 12,
                      cursor: 'pointer',
                      transition: 'all 150ms ease-in-out',
                    }}
                  >
                    {/* Token Icon */}
                    <div style={{ position: 'relative', marginRight: 12 }}>
                      {token.logo_url ? (
                        <img
                          src={token.logo_url}
                          alt={token.symbol}
                          style={{ width: 36, height: 36, borderRadius: '50%' }}
                          onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
                        />
                      ) : (
                        <div style={{
                          width: 36, height: 36, borderRadius: '50%',
                          background: 'var(--r-blue-light-1, #edf0ff)',
                          color: 'var(--r-blue-default, #4c65ff)',
                          display: 'flex', alignItems: 'center', justifyContent: 'center',
                          fontWeight: 600, fontSize: 14,
                        }}>
                          {token.symbol[0]}
                        </div>
                      )}
                    </div>

                    {/* Token Info */}
                    <div style={{ flex: 1 }}>
                      <div style={{
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center',
                        marginBottom: 4,
                      }}>
                        <span style={{
                          fontWeight: 600,
                          fontSize: 15,
                          color: 'var(--r-neutral-title-1, #192945)',
                        }}>
                          {token.display_symbol || token.symbol}
                        </span>
                        <span style={{
                          fontWeight: 600,
                          fontSize: 15,
                          color: 'var(--r-neutral-title-1, #192945)',
                        }}>
                          ${usdValue.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                        </span>
                      </div>
                      <div style={{
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center',
                      }}>
                        <span style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)' }}>
                          {token.amount.toLocaleString('en-US', { maximumFractionDigits: 6 })} {token.symbol}
                        </span>
                        <span style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)' }}>
                          ${token.price.toLocaleString('en-US', { maximumFractionDigits: 2 })}
                        </span>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}

      {/* NFT Tab Placeholder */}
      {activeTab === 'nft' && (
        <div style={{ textAlign: 'center', padding: 40, color: 'var(--r-neutral-foot, #6a7587)' }}>
          <div style={{ fontSize: 40, marginBottom: 12 }}>🖼</div>
          <div style={{ fontSize: 15, fontWeight: 500 }}>NFT Collection</div>
          <div style={{ fontSize: 13, marginTop: 8 }}>Your NFTs will appear here</div>
        </div>
      )}

      {/* DeFi Tab Placeholder */}
      {activeTab === 'defi' && (
        <div style={{ textAlign: 'center', padding: 40, color: 'var(--r-neutral-foot, #6a7587)' }}>
          <div style={{ fontSize: 40, marginBottom: 12 }}>📊</div>
          <div style={{ fontSize: 15, fontWeight: 500 }}>DeFi Protocols</div>
          <div style={{ fontSize: 13, marginTop: 8 }}>Your DeFi positions will appear here</div>
        </div>
      )}

      {/* Activity Tab Placeholder */}
      {activeTab === 'activity' && (
        <div style={{ textAlign: 'center', padding: 40, color: 'var(--r-neutral-foot, #6a7587)' }}>
          <div style={{ fontSize: 40, marginBottom: 12 }}>📋</div>
          <div style={{ fontSize: 15, fontWeight: 500 }}>Recent Activity</div>
          <div style={{ fontSize: 13, marginTop: 8 }}>Your recent transactions will appear here</div>
        </div>
      )}
    </div>
  );
}
