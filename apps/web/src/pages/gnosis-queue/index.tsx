import { useState } from 'react';
import { useWallet } from '../../contexts/WalletContext';

interface GnosisTransaction {
  nonce: number;
  description: string;
  to: string;
  value: string;
  confirmations: number;
  confirmationsRequired: number;
  status: 'pending' | 'ready' | 'executed';
  submittedAt: string;
}

const MOCK_QUEUE: GnosisTransaction[] = [
  {
    nonce: 42,
    description: 'Transfer 5 ETH to treasury',
    to: '0xaabb...ccdd',
    value: '5 ETH',
    confirmations: 1,
    confirmationsRequired: 3,
    status: 'pending',
    submittedAt: '2024-01-15 14:30',
  },
  {
    nonce: 43,
    description: 'Approve USDC spending for Uniswap',
    to: '0x1122...3344',
    value: '0 ETH',
    confirmations: 2,
    confirmationsRequired: 3,
    status: 'pending',
    submittedAt: '2024-01-15 15:10',
  },
  {
    nonce: 44,
    description: 'Swap 10,000 USDC to DAI',
    to: '0x5566...7788',
    value: '0 ETH',
    confirmations: 3,
    confirmationsRequired: 3,
    status: 'ready',
    submittedAt: '2024-01-15 16:45',
  },
  {
    nonce: 45,
    description: 'Add signer 0xdead...beef to Safe',
    to: '0x9900...aabb',
    value: '0 ETH',
    confirmations: 0,
    confirmationsRequired: 3,
    status: 'pending',
    submittedAt: '2024-01-16 09:00',
  },
];

function statusColor(status: GnosisTransaction['status']): string {
  if (status === 'ready') return 'var(--r-green-default, #27c193)';
  if (status === 'executed') return 'var(--r-neutral-foot, #6a7587)';
  return '#f5a623';
}

function statusLabel(status: GnosisTransaction['status']): string {
  if (status === 'ready') return 'Ready to Execute';
  if (status === 'executed') return 'Executed';
  return 'Awaiting Confirmations';
}

export default function GnosisQueuePage() {
  const { connected } = useWallet();
  const [transactions] = useState(MOCK_QUEUE);
  const [confirming, setConfirming] = useState<number | null>(null);
  const [executing, setExecuting] = useState<number | null>(null);

  const handleConfirm = async (nonce: number) => {
    setConfirming(nonce);
    await new Promise((r) => setTimeout(r, 1500));
    setConfirming(null);
  };

  const handleExecute = async (nonce: number) => {
    setExecuting(nonce);
    await new Promise((r) => setTimeout(r, 2000));
    setExecuting(null);
  };

  return (
    <div style={{ padding: 24, maxWidth: 700, margin: '0 auto' }}>
      <h2 style={{
        fontSize: 24,
        fontWeight: 600,
        color: 'var(--r-neutral-title-1, #192945)',
        marginBottom: 8,
      }}>
        Gnosis Safe Queue
      </h2>
      <p style={{
        fontSize: 13,
        color: 'var(--r-neutral-foot, #6a7587)',
        marginBottom: 24,
        lineHeight: 1.5,
      }}>
        Pending multi-signature transactions from your Gnosis Safe. Confirm or execute transactions when enough signatures have been collected.
      </p>

      {/* Info Banner */}
      <div style={{
        background: 'rgba(76,101,255,0.06)',
        borderRadius: 12,
        padding: '14px 18px',
        marginBottom: 20,
        display: 'flex',
        alignItems: 'center',
        gap: 12,
      }}>
        <div style={{
          width: 32,
          height: 32,
          borderRadius: '50%',
          background: 'var(--r-blue-default, #4c65ff)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          color: '#fff',
          fontSize: 16,
          fontWeight: 700,
          flexShrink: 0,
        }}>
          S
        </div>
        <div style={{ fontSize: 13, color: 'var(--r-neutral-title-1, #192945)', lineHeight: 1.5 }}>
          Safe requires <strong>3 of 5</strong> confirmations to execute transactions. You are signer #2.
        </div>
      </div>

      {/* Transaction List */}
      {!connected ? (
        <div style={{
          background: 'var(--r-neutral-card-1, #fff)',
          borderRadius: 16,
          padding: 40,
          textAlign: 'center',
        }}>
          <p style={{ color: 'var(--r-neutral-foot, #6a7587)', fontSize: 14 }}>
            Connect your wallet to view the Safe transaction queue.
          </p>
        </div>
      ) : transactions.length === 0 ? (
        <div style={{
          background: 'var(--r-neutral-card-1, #fff)',
          borderRadius: 16,
          padding: 40,
          textAlign: 'center',
        }}>
          <p style={{
            fontSize: 16,
            fontWeight: 500,
            color: 'var(--r-neutral-title-1, #192945)',
            marginBottom: 8,
          }}>
            No pending transactions
          </p>
          <p style={{ color: 'var(--r-neutral-foot, #6a7587)', fontSize: 13 }}>
            When there are pending multi-sig transactions, they will appear here.
          </p>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {transactions.map((tx) => (
            <div
              key={tx.nonce}
              style={{
                background: 'var(--r-neutral-card-1, #fff)',
                borderRadius: 16,
                padding: 20,
              }}
            >
              {/* Header row */}
              <div style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                marginBottom: 12,
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <span style={{
                    fontSize: 12,
                    fontWeight: 600,
                    color: 'var(--r-neutral-foot, #6a7587)',
                    background: 'var(--r-neutral-card-2, #f2f4f7)',
                    padding: '4px 10px',
                    borderRadius: 6,
                  }}>
                    #{tx.nonce}
                  </span>
                  <span style={{
                    fontSize: 12,
                    fontWeight: 500,
                    color: statusColor(tx.status),
                  }}>
                    {statusLabel(tx.status)}
                  </span>
                </div>
                <span style={{
                  fontSize: 11,
                  color: 'var(--r-neutral-foot, #6a7587)',
                }}>
                  {tx.submittedAt}
                </span>
              </div>

              {/* Description */}
              <div style={{
                fontSize: 15,
                fontWeight: 500,
                color: 'var(--r-neutral-title-1, #192945)',
                marginBottom: 8,
              }}>
                {tx.description}
              </div>

              {/* Details */}
              <div style={{
                display: 'flex',
                gap: 20,
                fontSize: 12,
                color: 'var(--r-neutral-foot, #6a7587)',
                marginBottom: 16,
              }}>
                <span>To: {tx.to}</span>
                <span>Value: {tx.value}</span>
              </div>

              {/* Confirmations bar */}
              <div style={{ marginBottom: 14 }}>
                <div style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  fontSize: 12,
                  color: 'var(--r-neutral-foot, #6a7587)',
                  marginBottom: 6,
                }}>
                  <span>Confirmations</span>
                  <span style={{ fontWeight: 600, color: 'var(--r-neutral-title-1, #192945)' }}>
                    {tx.confirmations} / {tx.confirmationsRequired}
                  </span>
                </div>
                <div style={{
                  height: 6,
                  borderRadius: 3,
                  background: 'var(--r-neutral-card-2, #f2f4f7)',
                  overflow: 'hidden',
                }}>
                  <div style={{
                    height: '100%',
                    width: `${(tx.confirmations / tx.confirmationsRequired) * 100}%`,
                    borderRadius: 3,
                    background: tx.confirmations >= tx.confirmationsRequired
                      ? 'var(--r-green-default, #27c193)'
                      : 'var(--r-blue-default, #4c65ff)',
                    transition: 'width 0.3s',
                  }} />
                </div>
              </div>

              {/* Action buttons */}
              <div style={{ display: 'flex', gap: 10 }}>
                {tx.status === 'ready' ? (
                  <button
                    onClick={() => handleExecute(tx.nonce)}
                    disabled={executing === tx.nonce}
                    style={{
                      flex: 1,
                      padding: '12px 0',
                      borderRadius: 8,
                      border: 'none',
                      background: 'var(--r-green-default, #27c193)',
                      color: '#fff',
                      fontSize: 14,
                      fontWeight: 600,
                      cursor: executing === tx.nonce ? 'not-allowed' : 'pointer',
                      opacity: executing === tx.nonce ? 0.6 : 1,
                      transition: 'opacity 0.2s',
                    }}
                  >
                    {executing === tx.nonce ? 'Executing...' : 'Execute'}
                  </button>
                ) : tx.status === 'pending' ? (
                  <button
                    onClick={() => handleConfirm(tx.nonce)}
                    disabled={confirming === tx.nonce}
                    style={{
                      flex: 1,
                      padding: '12px 0',
                      borderRadius: 8,
                      border: 'none',
                      background: 'var(--r-blue-default, #4c65ff)',
                      color: '#fff',
                      fontSize: 14,
                      fontWeight: 600,
                      cursor: confirming === tx.nonce ? 'not-allowed' : 'pointer',
                      opacity: confirming === tx.nonce ? 0.6 : 1,
                      transition: 'opacity 0.2s',
                    }}
                  >
                    {confirming === tx.nonce ? 'Confirming...' : 'Confirm'}
                  </button>
                ) : null}
                <button
                  style={{
                    padding: '12px 24px',
                    borderRadius: 8,
                    border: '1px solid var(--r-neutral-line, #e5e9ef)',
                    background: 'transparent',
                    color: 'var(--r-neutral-foot, #6a7587)',
                    fontSize: 14,
                    fontWeight: 500,
                    cursor: 'pointer',
                  }}
                >
                  Details
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
