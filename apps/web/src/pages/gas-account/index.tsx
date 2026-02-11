import React, { useState, useCallback } from 'react';
import { useWallet } from '../../contexts/WalletContext';

/* ─── Mock Data ─── */

interface GasHistoryItem {
  id: string;
  type: 'deposit' | 'withdraw' | 'gas_fee';
  amount: number;
  chain: string;
  timestamp: number;
  txHash: string;
  status: 'success' | 'pending' | 'failed';
  description: string;
}

const MOCK_BALANCE = 12.847;

const MOCK_HISTORY: GasHistoryItem[] = [
  {
    id: 'gh-1',
    type: 'gas_fee',
    amount: -0.0032,
    chain: 'Ethereum',
    timestamp: Date.now() - 1800_000,
    txHash: '0xabc123...def456',
    status: 'success',
    description: 'Swap on Uniswap V3',
  },
  {
    id: 'gh-2',
    type: 'gas_fee',
    amount: -0.00015,
    chain: 'Arbitrum',
    timestamp: Date.now() - 7200_000,
    txHash: '0xfed987...654cba',
    status: 'success',
    description: 'Transfer USDC',
  },
  {
    id: 'gh-3',
    type: 'deposit',
    amount: 5.0,
    chain: 'Ethereum',
    timestamp: Date.now() - 86400_000,
    txHash: '0x111222...333444',
    status: 'success',
    description: 'Deposit to Gas Account',
  },
  {
    id: 'gh-4',
    type: 'gas_fee',
    amount: -0.0087,
    chain: 'Ethereum',
    timestamp: Date.now() - 172800_000,
    txHash: '0x555666...777888',
    status: 'success',
    description: 'Approve USDT on Aave',
  },
  {
    id: 'gh-5',
    type: 'gas_fee',
    amount: -0.00042,
    chain: 'Optimism',
    timestamp: Date.now() - 259200_000,
    txHash: '0x999aaa...bbbccc',
    status: 'success',
    description: 'Bridge via Stargate',
  },
  {
    id: 'gh-6',
    type: 'withdraw',
    amount: -2.0,
    chain: 'Ethereum',
    timestamp: Date.now() - 345600_000,
    txHash: '0xddd111...222eee',
    status: 'success',
    description: 'Withdraw from Gas Account',
  },
  {
    id: 'gh-7',
    type: 'deposit',
    amount: 10.0,
    chain: 'Ethereum',
    timestamp: Date.now() - 604800_000,
    txHash: '0xfff333...444ggg',
    status: 'success',
    description: 'Initial Deposit',
  },
  {
    id: 'gh-8',
    type: 'gas_fee',
    amount: -0.0021,
    chain: 'Polygon',
    timestamp: Date.now() - 691200_000,
    txHash: '0xhhh555...666iii',
    status: 'pending',
    description: 'Swap on QuickSwap',
  },
];

const SUPPORTED_CHAINS = ['Ethereum', 'Arbitrum', 'Optimism', 'Polygon', 'BSC', 'Base'];

/* ─── Helpers ─── */

function formatUsd(value: number): string {
  return value.toLocaleString('en-US', { style: 'currency', currency: 'USD' });
}

function formatGasAmount(value: number): string {
  const abs = Math.abs(value);
  if (abs < 0.001) return value.toFixed(6);
  if (abs < 1) return value.toFixed(4);
  return value.toFixed(3);
}

function formatTimeAgo(timestamp: number): string {
  const diff = Date.now() - timestamp;
  const minutes = Math.floor(diff / 60000);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days}d ago`;
  return new Date(timestamp).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

function getTypeIcon(type: GasHistoryItem['type']): string {
  switch (type) {
    case 'deposit': return '+';
    case 'withdraw': return '-';
    case 'gas_fee': return 'G';
  }
}

function getTypeColor(type: GasHistoryItem['type']): string {
  switch (type) {
    case 'deposit': return 'var(--r-green-default, #27c193)';
    case 'withdraw': return 'var(--r-orange-default, #ffb020)';
    case 'gas_fee': return 'var(--r-blue-default, #4c65ff)';
  }
}

function getTypeBg(type: GasHistoryItem['type']): string {
  switch (type) {
    case 'deposit': return 'var(--r-green-light, #e8faf2)';
    case 'withdraw': return 'var(--r-orange-light, #fff5e0)';
    case 'gas_fee': return 'var(--r-blue-light-1, #edf0ff)';
  }
}

/* ─── Main Gas Account Page ─── */

export default function GasAccountPage() {
  const { currentAccount, connected, signMessage } = useWallet();

  const [authenticated, setAuthenticated] = useState(false);
  const [signing, setSigning] = useState(false);
  const [depositModalOpen, setDepositModalOpen] = useState(false);
  const [withdrawModalOpen, setWithdrawModalOpen] = useState(false);
  const [depositAmount, setDepositAmount] = useState('');
  const [withdrawAmount, setWithdrawAmount] = useState('');
  const [depositing, setDepositing] = useState(false);
  const [withdrawing, setWithdrawing] = useState(false);
  const [balance, setBalance] = useState(MOCK_BALANCE);

  /* Handlers */
  const handleLogin = useCallback(async () => {
    setSigning(true);
    try {
      const msg = `Sign this message to access your Rabby Gas Account\n\nTimestamp: ${Date.now()}`;
      await signMessage(msg);
      setAuthenticated(true);
    } catch {
      // User rejected or error
    } finally {
      setSigning(false);
    }
  }, [signMessage]);

  const handleDeposit = useCallback(async () => {
    const amt = Number(depositAmount);
    if (!amt || amt <= 0) return;
    setDepositing(true);
    try {
      await new Promise((r) => setTimeout(r, 2000));
      setBalance((prev) => prev + amt);
      setDepositAmount('');
      setDepositModalOpen(false);
    } catch {
      // error
    } finally {
      setDepositing(false);
    }
  }, [depositAmount]);

  const handleWithdraw = useCallback(async () => {
    const amt = Number(withdrawAmount);
    if (!amt || amt <= 0 || amt > balance) return;
    setWithdrawing(true);
    try {
      await new Promise((r) => setTimeout(r, 2000));
      setBalance((prev) => prev - amt);
      setWithdrawAmount('');
      setWithdrawModalOpen(false);
    } catch {
      // error
    } finally {
      setWithdrawing(false);
    }
  }, [withdrawAmount, balance]);

  /* ─── Styles ─── */
  const cardStyle: React.CSSProperties = {
    background: 'var(--r-neutral-card-1, #fff)',
    borderRadius: 16,
    boxShadow: 'var(--rabby-shadow-sm, 0 2px 4px rgba(0,0,0,0.04))',
  };

  /* ─── Login Prompt ─── */
  if (!connected || !authenticated) {
    return (
      <div style={{ maxWidth: 480, margin: '0 auto' }}>
        <h2 style={{
          fontSize: 20, fontWeight: 600, margin: '0 0 24px',
          color: 'var(--r-neutral-title-1, #192945)',
        }}>
          Gas Account
        </h2>

        <div style={{
          ...cardStyle,
          padding: '48px 32px',
          textAlign: 'center',
        }}>
          {/* Gas icon */}
          <div style={{
            width: 72, height: 72, borderRadius: '50%',
            background: 'linear-gradient(135deg, var(--r-blue-default, #4c65ff), #7b8dff)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            margin: '0 auto 20px', fontSize: 32, color: '#fff',
          }}>
            G
          </div>

          <div style={{
            fontSize: 18, fontWeight: 600,
            color: 'var(--r-neutral-title-1, #192945)',
            marginBottom: 8,
          }}>
            {!connected ? 'Connect Wallet' : 'Sign to Continue'}
          </div>

          <div style={{
            fontSize: 14, color: 'var(--r-neutral-foot, #6a7587)',
            marginBottom: 28, lineHeight: '1.5',
            maxWidth: 320, margin: '0 auto 28px',
          }}>
            {!connected
              ? 'Connect your wallet to access the Gas Account feature. Gas Account lets you pay gas fees across multiple chains from a single balance.'
              : 'Sign a message to verify your identity and access your Gas Account. No transaction will be sent.'}
          </div>

          <button
            onClick={handleLogin}
            disabled={signing}
            style={{
              padding: '14px 48px', borderRadius: 12,
              border: 'none',
              background: signing
                ? 'var(--r-neutral-foot, #6a7587)'
                : 'var(--r-blue-default, #4c65ff)',
              color: '#fff', fontSize: 15, fontWeight: 600,
              cursor: signing ? 'not-allowed' : 'pointer',
              transition: 'background 200ms',
            }}
          >
            {signing ? 'Signing...' : 'Sign Message'}
          </button>

          {/* Features list */}
          <div style={{ marginTop: 32, textAlign: 'left' }}>
            {[
              { label: 'Multi-chain gas', desc: 'Pay gas on any supported chain from one balance' },
              { label: 'No bridging needed', desc: 'Stop moving ETH between chains for gas' },
              { label: 'Auto top-up', desc: 'Set thresholds to automatically deposit when low' },
            ].map((item) => (
              <div key={item.label} style={{
                display: 'flex', gap: 12, padding: '10px 0',
                borderTop: '1px solid var(--r-neutral-line, #e0e5ec)',
              }}>
                <div style={{
                  width: 28, height: 28, borderRadius: 8,
                  background: 'var(--r-blue-light-1, #edf0ff)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 14, color: 'var(--r-blue-default, #4c65ff)',
                  flexShrink: 0, marginTop: 2,
                }}>
                  &#10003;
                </div>
                <div>
                  <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--r-neutral-title-1, #192945)', marginBottom: 2 }}>
                    {item.label}
                  </div>
                  <div style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)' }}>
                    {item.desc}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  /* ─── Deposit Modal ─── */
  const renderDepositModal = () => {
    if (!depositModalOpen) return null;
    const isValid = depositAmount && Number(depositAmount) > 0;
    return (
      <div style={{
        position: 'fixed', inset: 0, zIndex: 1000,
        background: 'rgba(0,0,0,0.4)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}
        onClick={() => !depositing && setDepositModalOpen(false)}
      >
        <div
          style={{
            background: 'var(--r-neutral-card-1, #fff)',
            borderRadius: 20, width: 400, padding: 24,
            boxShadow: '0 20px 60px rgba(0,0,0,0.15)',
          }}
          onClick={(e) => e.stopPropagation()}
        >
          <div style={{ fontWeight: 600, fontSize: 18, color: 'var(--r-neutral-title-1, #192945)', marginBottom: 20, textAlign: 'center' }}>
            Deposit to Gas Account
          </div>

          <div style={{ marginBottom: 16 }}>
            <div style={{ fontSize: 13, color: 'var(--r-neutral-foot, #6a7587)', marginBottom: 8 }}>
              Amount (USD)
            </div>
            <input
              type="text"
              placeholder="0.00"
              value={depositAmount}
              onChange={(e) => {
                if (/^\d*\.?\d*$/.test(e.target.value)) {
                  setDepositAmount(e.target.value);
                }
              }}
              autoFocus
              style={{
                width: '100%', padding: '14px 16px', borderRadius: 12,
                border: '1px solid var(--r-neutral-line, #e0e5ec)',
                background: 'var(--r-neutral-bg-2, #f2f4f7)',
                fontSize: 20, fontWeight: 600, outline: 'none',
                color: 'var(--r-neutral-title-1, #192945)',
                boxSizing: 'border-box',
              }}
            />
          </div>

          {/* Quick amounts */}
          <div style={{ display: 'flex', gap: 8, marginBottom: 20 }}>
            {[5, 10, 25, 50].map((amt) => (
              <button
                key={amt}
                onClick={() => setDepositAmount(String(amt))}
                style={{
                  flex: 1, padding: '8px 0', borderRadius: 8,
                  border: depositAmount === String(amt)
                    ? '1.5px solid var(--r-blue-default, #4c65ff)'
                    : '1px solid var(--r-neutral-line, #e0e5ec)',
                  background: depositAmount === String(amt)
                    ? 'var(--r-blue-light-1, #edf0ff)'
                    : 'transparent',
                  color: depositAmount === String(amt)
                    ? 'var(--r-blue-default, #4c65ff)'
                    : 'var(--r-neutral-body, #3e495e)',
                  fontSize: 13, fontWeight: 600, cursor: 'pointer',
                }}
              >
                ${amt}
              </button>
            ))}
          </div>

          <div style={{ display: 'flex', gap: 12 }}>
            <button
              onClick={() => { setDepositModalOpen(false); setDepositAmount(''); }}
              disabled={depositing}
              style={{
                flex: 1, padding: '14px 0', borderRadius: 12,
                border: '1px solid var(--r-neutral-line, #e0e5ec)',
                background: 'transparent', fontSize: 15, fontWeight: 600,
                cursor: depositing ? 'not-allowed' : 'pointer',
                color: 'var(--r-neutral-title-1, #192945)',
              }}
            >
              Cancel
            </button>
            <button
              onClick={handleDeposit}
              disabled={depositing || !isValid}
              style={{
                flex: 1, padding: '14px 0', borderRadius: 12,
                border: 'none',
                background: (depositing || !isValid)
                  ? 'var(--r-neutral-line, #e0e5ec)'
                  : 'var(--r-blue-default, #4c65ff)',
                color: (depositing || !isValid)
                  ? 'var(--r-neutral-foot, #6a7587)'
                  : '#fff',
                fontSize: 15, fontWeight: 600,
                cursor: (depositing || !isValid) ? 'not-allowed' : 'pointer',
              }}
            >
              {depositing ? 'Depositing...' : 'Deposit'}
            </button>
          </div>
        </div>
      </div>
    );
  };

  /* ─── Withdraw Modal ─── */
  const renderWithdrawModal = () => {
    if (!withdrawModalOpen) return null;
    const amt = Number(withdrawAmount);
    const isValid = withdrawAmount && amt > 0 && amt <= balance;
    return (
      <div style={{
        position: 'fixed', inset: 0, zIndex: 1000,
        background: 'rgba(0,0,0,0.4)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}
        onClick={() => !withdrawing && setWithdrawModalOpen(false)}
      >
        <div
          style={{
            background: 'var(--r-neutral-card-1, #fff)',
            borderRadius: 20, width: 400, padding: 24,
            boxShadow: '0 20px 60px rgba(0,0,0,0.15)',
          }}
          onClick={(e) => e.stopPropagation()}
        >
          <div style={{ fontWeight: 600, fontSize: 18, color: 'var(--r-neutral-title-1, #192945)', marginBottom: 20, textAlign: 'center' }}>
            Withdraw from Gas Account
          </div>

          <div style={{ marginBottom: 8 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
              <span style={{ fontSize: 13, color: 'var(--r-neutral-foot, #6a7587)' }}>
                Amount (USD)
              </span>
              <span style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)' }}>
                Available: {formatUsd(balance)}
              </span>
            </div>
            <div style={{ position: 'relative' }}>
              <input
                type="text"
                placeholder="0.00"
                value={withdrawAmount}
                onChange={(e) => {
                  if (/^\d*\.?\d*$/.test(e.target.value)) {
                    setWithdrawAmount(e.target.value);
                  }
                }}
                autoFocus
                style={{
                  width: '100%', padding: '14px 60px 14px 16px', borderRadius: 12,
                  border: amt > balance
                    ? '1px solid var(--r-red-default, #ec5151)'
                    : '1px solid var(--r-neutral-line, #e0e5ec)',
                  background: 'var(--r-neutral-bg-2, #f2f4f7)',
                  fontSize: 20, fontWeight: 600, outline: 'none',
                  color: 'var(--r-neutral-title-1, #192945)',
                  boxSizing: 'border-box',
                }}
              />
              <button
                onClick={() => setWithdrawAmount(String(balance))}
                style={{
                  position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)',
                  padding: '4px 10px', borderRadius: 4,
                  background: 'var(--r-blue-light-1, #edf0ff)',
                  color: 'var(--r-blue-default, #4c65ff)',
                  border: 'none', fontSize: 11, fontWeight: 700,
                  cursor: 'pointer',
                }}
              >
                MAX
              </button>
            </div>
            {amt > balance && (
              <div style={{ fontSize: 12, color: 'var(--r-red-default, #ec5151)', marginTop: 4 }}>
                Exceeds available balance
              </div>
            )}
          </div>

          <div style={{ height: 12 }} />

          <div style={{ display: 'flex', gap: 12 }}>
            <button
              onClick={() => { setWithdrawModalOpen(false); setWithdrawAmount(''); }}
              disabled={withdrawing}
              style={{
                flex: 1, padding: '14px 0', borderRadius: 12,
                border: '1px solid var(--r-neutral-line, #e0e5ec)',
                background: 'transparent', fontSize: 15, fontWeight: 600,
                cursor: withdrawing ? 'not-allowed' : 'pointer',
                color: 'var(--r-neutral-title-1, #192945)',
              }}
            >
              Cancel
            </button>
            <button
              onClick={handleWithdraw}
              disabled={withdrawing || !isValid}
              style={{
                flex: 1, padding: '14px 0', borderRadius: 12,
                border: 'none',
                background: (withdrawing || !isValid)
                  ? 'var(--r-neutral-line, #e0e5ec)'
                  : 'var(--r-blue-default, #4c65ff)',
                color: (withdrawing || !isValid)
                  ? 'var(--r-neutral-foot, #6a7587)'
                  : '#fff',
                fontSize: 15, fontWeight: 600,
                cursor: (withdrawing || !isValid) ? 'not-allowed' : 'pointer',
              }}
            >
              {withdrawing ? 'Withdrawing...' : 'Withdraw'}
            </button>
          </div>
        </div>
      </div>
    );
  };

  /* ─── Authenticated View ─── */
  return (
    <div style={{ maxWidth: 480, margin: '0 auto' }}>
      <h2 style={{
        fontSize: 20, fontWeight: 600, margin: '0 0 24px',
        color: 'var(--r-neutral-title-1, #192945)',
      }}>
        Gas Account
      </h2>

      {/* ─── Balance Card with Gradient ─── */}
      <div style={{
        borderRadius: 16,
        background: 'linear-gradient(135deg, #4c65ff 0%, #6b7fff 50%, #8b9dff 100%)',
        padding: '28px 24px',
        color: '#fff',
        marginBottom: 16,
        boxShadow: '0 8px 24px rgba(76, 101, 255, 0.25)',
        position: 'relative',
        overflow: 'hidden',
      }}>
        {/* Decorative circles */}
        <div style={{
          position: 'absolute', top: -30, right: -30,
          width: 120, height: 120, borderRadius: '50%',
          background: 'rgba(255,255,255,0.08)',
        }} />
        <div style={{
          position: 'absolute', bottom: -20, left: -20,
          width: 80, height: 80, borderRadius: '50%',
          background: 'rgba(255,255,255,0.06)',
        }} />

        <div style={{ position: 'relative', zIndex: 1 }}>
          <div style={{ fontSize: 13, opacity: 0.8, marginBottom: 4 }}>
            Gas Account Balance
          </div>
          <div style={{ fontSize: 36, fontWeight: 700, letterSpacing: '-1px', marginBottom: 4 }}>
            {formatUsd(balance)}
          </div>
          <div style={{ fontSize: 12, opacity: 0.65 }}>
            {currentAccount?.address
              ? `${currentAccount.address.slice(0, 6)}...${currentAccount.address.slice(-4)}`
              : ''}
          </div>

          {/* Supported chains */}
          <div style={{ display: 'flex', gap: 6, marginTop: 16, flexWrap: 'wrap' }}>
            {SUPPORTED_CHAINS.map((chain) => (
              <span key={chain} style={{
                padding: '3px 10px', borderRadius: 6,
                background: 'rgba(255,255,255,0.15)',
                fontSize: 11, fontWeight: 600,
              }}>
                {chain}
              </span>
            ))}
          </div>
        </div>
      </div>

      {/* ─── Action Buttons ─── */}
      <div style={{ display: 'flex', gap: 12, marginBottom: 20 }}>
        <button
          onClick={() => setDepositModalOpen(true)}
          style={{
            flex: 1, padding: '14px 0', borderRadius: 12,
            border: 'none',
            background: 'var(--r-blue-default, #4c65ff)',
            color: '#fff', fontSize: 15, fontWeight: 600,
            cursor: 'pointer',
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
            transition: 'opacity 200ms',
          }}
          onMouseEnter={(e) => (e.currentTarget.style.opacity = '0.9')}
          onMouseLeave={(e) => (e.currentTarget.style.opacity = '1')}
        >
          <span style={{ fontSize: 18 }}>+</span>
          Deposit
        </button>
        <button
          onClick={() => setWithdrawModalOpen(true)}
          style={{
            flex: 1, padding: '14px 0', borderRadius: 12,
            border: '1.5px solid var(--r-neutral-line, #e0e5ec)',
            background: 'var(--r-neutral-card-1, #fff)',
            color: 'var(--r-neutral-title-1, #192945)',
            fontSize: 15, fontWeight: 600,
            cursor: 'pointer',
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
            boxShadow: 'var(--rabby-shadow-sm, 0 2px 4px rgba(0,0,0,0.04))',
            transition: 'border-color 200ms',
          }}
          onMouseEnter={(e) => (e.currentTarget.style.borderColor = 'var(--r-blue-default, #4c65ff)')}
          onMouseLeave={(e) => (e.currentTarget.style.borderColor = 'var(--r-neutral-line, #e0e5ec)')}
        >
          <span style={{ fontSize: 18 }}>-</span>
          Withdraw
        </button>
      </div>

      {/* ─── Transaction History ─── */}
      <div style={{
        ...cardStyle,
        padding: '16px 0',
      }}>
        <div style={{
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          padding: '0 20px 12px',
          borderBottom: '1px solid var(--r-neutral-line, #e0e5ec)',
        }}>
          <span style={{ fontSize: 15, fontWeight: 600, color: 'var(--r-neutral-title-1, #192945)' }}>
            Transaction History
          </span>
          <span style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)' }}>
            {MOCK_HISTORY.length} transactions
          </span>
        </div>

        {MOCK_HISTORY.length === 0 ? (
          <div style={{
            padding: '48px 24px', textAlign: 'center',
          }}>
            <div style={{ fontSize: 14, color: 'var(--r-neutral-foot, #6a7587)' }}>
              No transactions yet
            </div>
          </div>
        ) : (
          <div>
            {MOCK_HISTORY.map((item, i) => (
              <div
                key={item.id}
                style={{
                  display: 'flex', alignItems: 'center', gap: 12,
                  padding: '12px 20px',
                  borderBottom: i < MOCK_HISTORY.length - 1
                    ? '1px solid var(--r-neutral-line, #e0e5ec)'
                    : 'none',
                  transition: 'background 150ms',
                  cursor: 'default',
                }}
                onMouseEnter={(e) => (e.currentTarget.style.background = 'var(--r-neutral-bg-2, #f2f4f7)')}
                onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
              >
                {/* Type icon */}
                <div style={{
                  width: 36, height: 36, borderRadius: 10,
                  background: getTypeBg(item.type),
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 14, fontWeight: 700,
                  color: getTypeColor(item.type),
                  flexShrink: 0,
                }}>
                  {getTypeIcon(item.type)}
                </div>

                {/* Description */}
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{
                    fontSize: 14, fontWeight: 500,
                    color: 'var(--r-neutral-title-1, #192945)',
                    marginBottom: 2,
                    overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
                  }}>
                    {item.description}
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                    <span style={{ fontSize: 11, color: 'var(--r-neutral-foot, #6a7587)' }}>
                      {item.chain}
                    </span>
                    <span style={{
                      width: 3, height: 3, borderRadius: '50%',
                      background: 'var(--r-neutral-foot, #6a7587)', opacity: 0.4,
                    }} />
                    <span style={{ fontSize: 11, color: 'var(--r-neutral-foot, #6a7587)' }}>
                      {formatTimeAgo(item.timestamp)}
                    </span>
                    {item.status === 'pending' && (
                      <span style={{
                        padding: '1px 6px', borderRadius: 4,
                        background: 'var(--r-orange-light, #fff5e0)',
                        color: 'var(--r-orange-default, #ffb020)',
                        fontSize: 10, fontWeight: 600,
                      }}>
                        Pending
                      </span>
                    )}
                  </div>
                </div>

                {/* Amount */}
                <div style={{
                  textAlign: 'right', flexShrink: 0,
                }}>
                  <div style={{
                    fontSize: 14, fontWeight: 600,
                    color: item.amount > 0
                      ? 'var(--r-green-default, #27c193)'
                      : 'var(--r-neutral-title-1, #192945)',
                  }}>
                    {item.amount > 0 ? '+' : ''}{formatUsd(Math.abs(item.amount))}
                  </div>
                  <div style={{ fontSize: 11, color: 'var(--r-neutral-foot, #6a7587)' }}>
                    {item.type === 'gas_fee' ? 'Gas fee' : item.type === 'deposit' ? 'Deposit' : 'Withdrawal'}
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Modals */}
      {renderDepositModal()}
      {renderWithdrawModal()}
    </div>
  );
}
