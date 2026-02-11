import { useState, useCallback } from 'react';
import { useWallet } from '../../contexts/WalletContext';
import type { Account } from '../../contexts/WalletContext';

function truncateAddress(addr: string): string {
  if (addr.length <= 14) return addr;
  return addr.slice(0, 8) + '...' + addr.slice(-6);
}

function getTypeBadge(type: string): { label: string; color: string; bg: string } {
  const t = type.toLowerCase();
  if (t.includes('hd') || t.includes('mnemonic'))
    return { label: 'HD', color: '#7084ff', bg: 'rgba(112,132,255,0.1)' };
  if (t.includes('private') || t.includes('simple'))
    return { label: 'Private Key', color: '#f5a623', bg: 'rgba(245,166,35,0.1)' };
  if (t.includes('watch'))
    return { label: 'Watch', color: '#6a7587', bg: 'rgba(106,117,135,0.1)' };
  if (t.includes('hardware') || t.includes('ledger') || t.includes('trezor') || t.includes('keystone'))
    return { label: 'Hardware', color: '#2abb7f', bg: 'rgba(42,187,127,0.1)' };
  if (t.includes('walletconnect'))
    return { label: 'WalletConnect', color: '#3b99fc', bg: 'rgba(59,153,252,0.1)' };
  return { label: type, color: '#6a7587', bg: 'rgba(106,117,135,0.1)' };
}

const CHAIN_ICONS = ['ETH', 'BSC', 'MATIC', 'ARB'];

export default function AddressManagement() {
  const { accounts, currentAccount, setCurrentAccount } = useWallet();
  const [editingAlias, setEditingAlias] = useState<string | null>(null);
  const [aliasValue, setAliasValue] = useState('');
  const [aliases, setAliases] = useState<Record<string, string>>({});
  const [showAddModal, setShowAddModal] = useState(false);

  const handleStartEdit = useCallback((address: string, currentAlias: string) => {
    setEditingAlias(address);
    setAliasValue(currentAlias);
  }, []);

  const handleSaveAlias = useCallback((address: string) => {
    setAliases((prev) => ({ ...prev, [address]: aliasValue }));
    setEditingAlias(null);
    setAliasValue('');
  }, [aliasValue]);

  const handleDelete = useCallback(
    (address: string) => {
      // In a real implementation this would call a wallet method to remove the account
      console.log('Delete address:', address);
    },
    []
  );

  const getAlias = (account: Account): string => {
    return aliases[account.address] || account.alianName || account.brandName || '';
  };

  const isCurrent = (account: Account): boolean => {
    return currentAccount
      ? currentAccount.address.toLowerCase() === account.address.toLowerCase()
      : false;
  };

  return (
    <div style={{ maxWidth: 780, margin: '0 auto', padding: '0 20px' }}>
      {/* Header */}
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: 24,
        }}
      >
        <div>
          <h2
            style={{
              margin: 0,
              fontSize: 24,
              fontWeight: 600,
              color: 'var(--r-neutral-title-1, #192945)',
            }}
          >
            Address Management
          </h2>
          <p
            style={{
              margin: '6px 0 0',
              fontSize: 14,
              color: 'var(--r-neutral-foot, #6a7587)',
            }}
          >
            {accounts.length} address{accounts.length !== 1 ? 'es' : ''} total
          </p>
        </div>
        <button
          onClick={() => setShowAddModal(true)}
          style={{
            padding: '10px 24px',
            background: 'var(--r-blue-default, #4c65ff)',
            color: '#fff',
            border: 'none',
            borderRadius: 8,
            fontSize: 14,
            fontWeight: 500,
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            gap: 6,
          }}
        >
          <span style={{ fontSize: 18, lineHeight: 1 }}>+</span>
          Add Address
        </button>
      </div>

      {/* Empty state */}
      {accounts.length === 0 ? (
        <div
          style={{
            background: 'var(--r-neutral-card-1, #fff)',
            borderRadius: 16,
            padding: '60px 20px',
            textAlign: 'center',
          }}
        >
          <div
            style={{
              width: 64,
              height: 64,
              borderRadius: '50%',
              background: 'var(--r-neutral-card-2, #f2f4f7)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              margin: '0 auto 16px',
              fontSize: 28,
              color: 'var(--r-neutral-foot, #6a7587)',
            }}
          >
            {/* Wallet icon placeholder */}
            W
          </div>
          <p
            style={{
              fontSize: 15,
              color: 'var(--r-neutral-foot, #6a7587)',
              margin: 0,
            }}
          >
            No addresses yet. Connect a wallet to get started.
          </p>
        </div>
      ) : (
        /* Address list */
        <div
          style={{
            background: 'var(--r-neutral-card-1, #fff)',
            borderRadius: 16,
            overflow: 'hidden',
          }}
        >
          {accounts.map((account, index) => {
            const current = isCurrent(account);
            const badge = getTypeBadge(account.type);
            const alias = getAlias(account);
            const isEditing = editingAlias === account.address;

            return (
              <div
                key={account.address}
                style={{
                  padding: '16px 20px',
                  display: 'flex',
                  alignItems: 'center',
                  gap: 14,
                  borderBottom:
                    index < accounts.length - 1
                      ? '1px solid var(--r-neutral-line, #e5e9ef)'
                      : 'none',
                  background: current
                    ? 'var(--r-blue-light-1, rgba(76,101,255,0.06))'
                    : 'transparent',
                  cursor: 'pointer',
                  transition: 'background 0.15s',
                }}
                onClick={() => {
                  if (!current && !isEditing) {
                    setCurrentAccount(account);
                  }
                }}
                onMouseEnter={(e) => {
                  if (!current) {
                    (e.currentTarget as HTMLElement).style.background =
                      'var(--r-neutral-card-2, #f7f8fa)';
                  }
                }}
                onMouseLeave={(e) => {
                  (e.currentTarget as HTMLElement).style.background = current
                    ? 'var(--r-blue-light-1, rgba(76,101,255,0.06))'
                    : 'transparent';
                }}
              >
                {/* Avatar / index indicator */}
                <div
                  style={{
                    width: 40,
                    height: 40,
                    borderRadius: '50%',
                    background: current
                      ? 'var(--r-blue-default, #4c65ff)'
                      : 'var(--r-neutral-card-2, #f2f4f7)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: 14,
                    fontWeight: 600,
                    color: current ? '#fff' : 'var(--r-neutral-foot, #6a7587)',
                    flexShrink: 0,
                  }}
                >
                  {index + 1}
                </div>

                {/* Main info */}
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: 8,
                      marginBottom: 4,
                    }}
                  >
                    {/* Alias / editable name */}
                    {isEditing ? (
                      <div
                        style={{ display: 'flex', alignItems: 'center', gap: 6 }}
                        onClick={(e) => e.stopPropagation()}
                      >
                        <input
                          type="text"
                          value={aliasValue}
                          onChange={(e) => setAliasValue(e.target.value)}
                          onKeyDown={(e) => {
                            if (e.key === 'Enter') handleSaveAlias(account.address);
                            if (e.key === 'Escape') setEditingAlias(null);
                          }}
                          autoFocus
                          style={{
                            padding: '4px 8px',
                            border: '1px solid var(--r-blue-default, #4c65ff)',
                            borderRadius: 6,
                            fontSize: 14,
                            outline: 'none',
                            width: 160,
                            color: 'var(--r-neutral-title-1, #192945)',
                            background: 'var(--r-neutral-card-1, #fff)',
                          }}
                        />
                        <button
                          onClick={() => handleSaveAlias(account.address)}
                          style={{
                            padding: '4px 10px',
                            background: 'var(--r-blue-default, #4c65ff)',
                            color: '#fff',
                            border: 'none',
                            borderRadius: 6,
                            fontSize: 12,
                            cursor: 'pointer',
                          }}
                        >
                          Save
                        </button>
                        <button
                          onClick={() => setEditingAlias(null)}
                          style={{
                            padding: '4px 10px',
                            background: 'var(--r-neutral-card-2, #f2f4f7)',
                            color: 'var(--r-neutral-foot, #6a7587)',
                            border: 'none',
                            borderRadius: 6,
                            fontSize: 12,
                            cursor: 'pointer',
                          }}
                        >
                          Cancel
                        </button>
                      </div>
                    ) : (
                      <span
                        style={{
                          fontSize: 15,
                          fontWeight: 500,
                          color: 'var(--r-neutral-title-1, #192945)',
                        }}
                      >
                        {alias || 'Unnamed'}
                      </span>
                    )}

                    {/* Type badge */}
                    <span
                      style={{
                        fontSize: 11,
                        fontWeight: 500,
                        color: badge.color,
                        background: badge.bg,
                        padding: '2px 8px',
                        borderRadius: 4,
                        whiteSpace: 'nowrap',
                      }}
                    >
                      {badge.label}
                    </span>

                    {current && (
                      <span
                        style={{
                          fontSize: 11,
                          fontWeight: 500,
                          color: 'var(--r-blue-default, #4c65ff)',
                          background: 'var(--r-blue-light-1, rgba(76,101,255,0.1))',
                          padding: '2px 8px',
                          borderRadius: 4,
                        }}
                      >
                        Current
                      </span>
                    )}
                  </div>

                  {/* Address row */}
                  <div
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: 10,
                    }}
                  >
                    <span
                      style={{
                        fontSize: 13,
                        fontFamily:
                          "'SF Mono', 'Roboto Mono', 'Fira Code', monospace",
                        color: 'var(--r-neutral-body, #3e495e)',
                        letterSpacing: '0.02em',
                      }}
                    >
                      {truncateAddress(account.address)}
                    </span>

                    {/* Chain icons */}
                    <div style={{ display: 'flex', gap: 2 }}>
                      {CHAIN_ICONS.map((chain) => (
                        <div
                          key={chain}
                          style={{
                            width: 18,
                            height: 18,
                            borderRadius: '50%',
                            background: 'var(--r-neutral-card-2, #f2f4f7)',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            fontSize: 8,
                            fontWeight: 600,
                            color: 'var(--r-neutral-foot, #6a7587)',
                            border: '1px solid var(--r-neutral-line, #e5e9ef)',
                          }}
                          title={chain}
                        >
                          {chain[0]}
                        </div>
                      ))}
                    </div>
                  </div>

                  {/* Balance summary */}
                  {typeof account.balance === 'number' && (
                    <div
                      style={{
                        marginTop: 4,
                        fontSize: 12,
                        color: 'var(--r-neutral-foot, #6a7587)',
                      }}
                    >
                      ${account.balance.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                    </div>
                  )}
                </div>

                {/* Action buttons */}
                <div
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 4,
                    flexShrink: 0,
                  }}
                  onClick={(e) => e.stopPropagation()}
                >
                  {/* Edit alias button */}
                  <button
                    onClick={() => handleStartEdit(account.address, alias)}
                    title="Edit alias"
                    style={{
                      width: 32,
                      height: 32,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      background: 'transparent',
                      border: 'none',
                      borderRadius: 8,
                      cursor: 'pointer',
                      color: 'var(--r-neutral-foot, #6a7587)',
                      fontSize: 14,
                      transition: 'background 0.15s',
                    }}
                    onMouseEnter={(e) => {
                      (e.currentTarget as HTMLElement).style.background =
                        'var(--r-neutral-card-2, #f2f4f7)';
                    }}
                    onMouseLeave={(e) => {
                      (e.currentTarget as HTMLElement).style.background = 'transparent';
                    }}
                  >
                    {/* Pencil icon SVG */}
                    <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                      <path
                        d="M11.333 2a1.414 1.414 0 0 1 2 2L5 12.333l-2.667.667.667-2.667L11.333 2Z"
                        stroke="currentColor"
                        strokeWidth="1.2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      />
                    </svg>
                  </button>

                  {/* Delete button */}
                  <button
                    onClick={() => handleDelete(account.address)}
                    title="Delete address"
                    style={{
                      width: 32,
                      height: 32,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      background: 'transparent',
                      border: 'none',
                      borderRadius: 8,
                      cursor: 'pointer',
                      color: 'var(--r-neutral-foot, #6a7587)',
                      fontSize: 14,
                      transition: 'background 0.15s, color 0.15s',
                    }}
                    onMouseEnter={(e) => {
                      const el = e.currentTarget as HTMLElement;
                      el.style.background = 'rgba(236,81,81,0.08)';
                      el.style.color = '#ec5151';
                    }}
                    onMouseLeave={(e) => {
                      const el = e.currentTarget as HTMLElement;
                      el.style.background = 'transparent';
                      el.style.color = 'var(--r-neutral-foot, #6a7587)';
                    }}
                  >
                    {/* Trash icon SVG */}
                    <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                      <path
                        d="M2 4h12M5.333 4V2.667a1.333 1.333 0 0 1 1.334-1.334h2.666a1.333 1.333 0 0 1 1.334 1.334V4m2 0v9.333a1.333 1.333 0 0 1-1.334 1.334H4.667a1.333 1.333 0 0 1-1.334-1.334V4h9.334Z"
                        stroke="currentColor"
                        strokeWidth="1.2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      />
                    </svg>
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Add Address Modal */}
      {showAddModal && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(0,0,0,0.4)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
          }}
          onClick={() => setShowAddModal(false)}
        >
          <div
            style={{
              background: 'var(--r-neutral-card-1, #fff)',
              borderRadius: 16,
              padding: 32,
              width: 420,
              maxWidth: '90vw',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <h3
              style={{
                margin: '0 0 20px',
                fontSize: 18,
                fontWeight: 600,
                color: 'var(--r-neutral-title-1, #192945)',
              }}
            >
              Add Address
            </h3>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {[
                { label: 'HD Wallet (Mnemonic)', desc: 'Import via seed phrase', icon: 'H' },
                { label: 'Private Key', desc: 'Import a single private key', icon: 'K' },
                { label: 'Watch Address', desc: 'Add a read-only address', icon: 'W' },
                { label: 'Hardware Wallet', desc: 'Connect Ledger, Trezor, etc.', icon: 'L' },
              ].map((item) => (
                <button
                  key={item.label}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 14,
                    padding: '14px 16px',
                    background: 'var(--r-neutral-card-2, #f7f8fa)',
                    border: 'none',
                    borderRadius: 12,
                    cursor: 'pointer',
                    textAlign: 'left',
                    transition: 'background 0.15s',
                  }}
                  onMouseEnter={(e) => {
                    (e.currentTarget as HTMLElement).style.background =
                      'var(--r-blue-light-1, rgba(76,101,255,0.08))';
                  }}
                  onMouseLeave={(e) => {
                    (e.currentTarget as HTMLElement).style.background =
                      'var(--r-neutral-card-2, #f7f8fa)';
                  }}
                >
                  <div
                    style={{
                      width: 40,
                      height: 40,
                      borderRadius: 10,
                      background: 'var(--r-blue-default, #4c65ff)',
                      color: '#fff',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontSize: 16,
                      fontWeight: 600,
                      flexShrink: 0,
                    }}
                  >
                    {item.icon}
                  </div>
                  <div>
                    <div
                      style={{
                        fontSize: 14,
                        fontWeight: 500,
                        color: 'var(--r-neutral-title-1, #192945)',
                      }}
                    >
                      {item.label}
                    </div>
                    <div
                      style={{
                        fontSize: 12,
                        color: 'var(--r-neutral-foot, #6a7587)',
                        marginTop: 2,
                      }}
                    >
                      {item.desc}
                    </div>
                  </div>
                </button>
              ))}
            </div>

            <button
              onClick={() => setShowAddModal(false)}
              style={{
                marginTop: 20,
                width: '100%',
                padding: '10px 0',
                background: 'transparent',
                border: '1px solid var(--r-neutral-line, #e5e9ef)',
                borderRadius: 8,
                fontSize: 14,
                color: 'var(--r-neutral-foot, #6a7587)',
                cursor: 'pointer',
              }}
            >
              Cancel
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
