import React, { useState, useMemo } from 'react';
import { useWallet } from '../../contexts/WalletContext';
import type { TxHistoryItem } from '@rabby/shared';

// Mock data
const MOCK_HISTORY: TxHistoryItem[] = [
  {
    id: 'tx1',
    chain: 'eth',
    cate_id: 'send',
    project_id: null,
    time_at: Date.now() / 1000 - 120,
    sends: [{ amount: 0.5, to_addr: '0xabcdef1234567890abcdef1234567890abcdef12', token_id: 'eth', token: { id: 'eth', chain: 'eth', name: 'Ethereum', symbol: 'ETH', decimals: 18, logo_url: '', price: 2345, amount: 0.5 } }],
    receives: [],
    tx: { eth_gas_fee: 0.002, usd_gas_fee: 4.69, value: 0.5, from: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1', to: '0xabcdef1234567890abcdef1234567890abcdef12', name: 'send', status: 1 },
  },
  {
    id: 'tx2',
    chain: 'eth',
    cate_id: 'swap',
    project_id: 'uniswap',
    time_at: Date.now() / 1000 - 3600,
    sends: [{ amount: 0.3, to_addr: '0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45', token_id: 'eth', token: { id: 'eth', chain: 'eth', name: 'Ethereum', symbol: 'ETH', decimals: 18, logo_url: '', price: 2345, amount: 0.3 } }],
    receives: [{ amount: 570, from_addr: '0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45', token_id: 'usdc', token: { id: 'usdc', chain: 'eth', name: 'USD Coin', symbol: 'USDC', decimals: 6, logo_url: '', price: 1, amount: 570 } }],
    tx: { eth_gas_fee: 0.003, usd_gas_fee: 7.04, value: 0.3, from: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1', to: '0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45', name: 'swap', status: 1 },
  },
  {
    id: 'tx3',
    chain: 'arb',
    cate_id: 'receive',
    project_id: null,
    time_at: Date.now() / 1000 - 43200,
    sends: [],
    receives: [{ amount: 2.0, from_addr: '0xffff0000111122223333444455556666777788889999', token_id: 'eth', token: { id: 'eth', chain: 'arb', name: 'Ethereum', symbol: 'ETH', decimals: 18, logo_url: '', price: 2345, amount: 2.0 } }],
    tx: { eth_gas_fee: 0.0001, usd_gas_fee: 0.23, value: 2.0, from: '0xffff0000111122223333444455556666777788889999', to: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1', name: 'receive', status: 1 },
  },
  {
    id: 'tx4',
    chain: 'eth',
    cate_id: 'approve',
    project_id: 'uniswap',
    time_at: Date.now() / 1000 - 72000,
    sends: [],
    receives: [],
    token_approve: {
      spender: '0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45',
      token_id: 'usdc',
      value: -1,
      token: { id: 'usdc', chain: 'eth', name: 'USD Coin', symbol: 'USDC', decimals: 6, logo_url: '', price: 1, amount: 0 },
    },
    tx: { eth_gas_fee: 0.001, usd_gas_fee: 2.35, value: 0, from: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1', to: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48', name: 'approve', status: 1 },
  },
];

const TX_TYPE_CONFIG: Record<string, { icon: string; color: string; label: string }> = {
  send: { icon: '\u2191', color: 'var(--r-red-default, #e34935)', label: 'Send' },
  receive: { icon: '\u2193', color: 'var(--r-green-default, #2abb7f)', label: 'Receive' },
  swap: { icon: '\u21C4', color: 'var(--r-blue-default, #4c65ff)', label: 'Swap' },
  approve: { icon: '\u2713', color: 'var(--r-orange-default, #ffb020)', label: 'Approve' },
  bridge: { icon: '\u2194', color: '#8b5cf6', label: 'Bridge' },
  contract: { icon: '\u25A1', color: 'var(--r-neutral-foot, #6a7587)', label: 'Contract' },
};

function formatTimeAgo(timestamp: number): string {
  const now = Date.now() / 1000;
  const diff = now - timestamp;
  if (diff < 60) return 'Just now';
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  if (diff < 604800) return `${Math.floor(diff / 86400)}d ago`;
  return new Date(timestamp * 1000).toLocaleDateString();
}

function groupByDate(items: TxHistoryItem[]): Record<string, TxHistoryItem[]> {
  const groups: Record<string, TxHistoryItem[]> = {};
  const now = new Date();
  const todayStr = now.toDateString();
  const yesterday = new Date(now);
  yesterday.setDate(yesterday.getDate() - 1);
  const yesterdayStr = yesterday.toDateString();

  for (const item of items) {
    const date = new Date(item.time_at * 1000);
    const dateStr = date.toDateString();
    let label: string;
    if (dateStr === todayStr) label = 'Today';
    else if (dateStr === yesterdayStr) label = 'Yesterday';
    else label = date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });

    if (!groups[label]) groups[label] = [];
    groups[label].push(item);
  }
  return groups;
}

export default function History() {
  const { connected } = useWallet();
  const [chainFilter, setChainFilter] = useState<string>('all');
  const history = MOCK_HISTORY;

  const filteredHistory = useMemo(() => {
    if (chainFilter === 'all') return history;
    return history.filter((tx) => tx.chain === chainFilter);
  }, [history, chainFilter]);

  const grouped = useMemo(() => groupByDate(filteredHistory), [filteredHistory]);
  const chainOptions = useMemo(() => {
    const set = new Set(history.map((tx) => tx.chain));
    return ['all', ...Array.from(set)];
  }, [history]);

  if (!connected) {
    return (
      <div style={{ textAlign: 'center', padding: 60 }}>
        <div style={{ fontSize: 48, marginBottom: 16 }}>&#x1F4CB;</div>
        <h2 style={{ color: 'var(--r-neutral-title-1)', margin: '0 0 8px' }}>Transaction History</h2>
        <p style={{ color: 'var(--r-neutral-foot)' }}>Connect wallet to view history</p>
      </div>
    );
  }

  return (
    <div>
      {/* Header */}
      <div style={{
        display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        marginBottom: 20,
      }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, margin: 0, color: 'var(--r-neutral-title-1, #192945)' }}>
          Transaction History
        </h2>
        {/* Chain Filter */}
        <div style={{ display: 'flex', gap: 6 }}>
          {chainOptions.map((chain) => (
            <button
              key={chain}
              onClick={() => setChainFilter(chain)}
              style={{
                padding: '4px 12px',
                borderRadius: 20,
                border: 'none',
                background: chainFilter === chain ? 'var(--r-blue-default, #4c65ff)' : 'var(--r-neutral-card-1, #fff)',
                color: chainFilter === chain ? '#fff' : 'var(--r-neutral-body, #3e495e)',
                fontSize: 12,
                fontWeight: 500,
                cursor: 'pointer',
              }}
            >
              {chain === 'all' ? 'All' : chain.toUpperCase()}
            </button>
          ))}
        </div>
      </div>

      {/* Transaction Groups */}
      {Object.entries(grouped).length === 0 ? (
        <div style={{ textAlign: 'center', padding: 40, color: 'var(--r-neutral-foot)' }}>
          No transactions found
        </div>
      ) : (
        Object.entries(grouped).map(([dateLabel, txs]) => (
          <div key={dateLabel} style={{ marginBottom: 20 }}>
            <div style={{
              fontSize: 13, fontWeight: 600, color: 'var(--r-neutral-foot, #6a7587)',
              marginBottom: 8, paddingLeft: 4,
            }}>
              {dateLabel}
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
              {txs.map((tx) => {
                const type = tx.cate_id || 'contract';
                const config = TX_TYPE_CONFIG[type] || TX_TYPE_CONFIG.contract;
                const isSuccess = tx.tx?.status === 1;

                let description = '';
                if (type === 'send' && tx.sends[0]) {
                  description = `${tx.sends[0].amount} ${tx.sends[0].token?.symbol || ''}`;
                } else if (type === 'receive' && tx.receives[0]) {
                  description = `+${tx.receives[0].amount} ${tx.receives[0].token?.symbol || ''}`;
                } else if (type === 'swap' && tx.sends[0] && tx.receives[0]) {
                  description = `${tx.sends[0].amount} ${tx.sends[0].token?.symbol} \u2192 ${tx.receives[0].amount} ${tx.receives[0].token?.symbol}`;
                } else if (type === 'approve' && tx.token_approve) {
                  const tokenSym = tx.token_approve.token?.symbol || '';
                  description = tx.token_approve.value === -1 ? `Unlimited ${tokenSym}` : `${tx.token_approve.value} ${tokenSym}`;
                }

                return (
                  <div
                    key={tx.id}
                    style={{
                      display: 'flex', alignItems: 'center', gap: 12,
                      padding: '14px 16px',
                      background: 'var(--r-neutral-card-1, #fff)',
                      borderRadius: 12,
                      cursor: 'pointer',
                    }}
                  >
                    {/* Type Icon */}
                    <div style={{
                      width: 40, height: 40, borderRadius: '50%',
                      background: `${config.color}15`,
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      fontSize: 18, flexShrink: 0,
                    }}>
                      {config.icon}
                    </div>

                    {/* Info */}
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                        <span style={{ fontWeight: 600, fontSize: 14, color: 'var(--r-neutral-title-1, #192945)' }}>
                          {config.label}
                        </span>
                        <span style={{
                          fontWeight: 600, fontSize: 14,
                          color: type === 'receive' ? 'var(--r-green-default, #2abb7f)' : type === 'send' ? 'var(--r-red-default, #e34935)' : 'var(--r-neutral-title-1, #192945)',
                        }}>
                          {type === 'send' ? '-' : type === 'receive' ? '+' : ''}{description}
                        </span>
                      </div>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                          <span style={{
                            padding: '2px 6px', borderRadius: 4,
                            background: 'var(--r-neutral-bg-2, #f2f4f7)',
                            fontSize: 11, color: 'var(--r-neutral-foot, #6a7587)',
                          }}>
                            {tx.chain.toUpperCase()}
                          </span>
                          <span style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)' }}>
                            {formatTimeAgo(tx.time_at)}
                          </span>
                        </div>
                        <span style={{
                          fontSize: 12,
                          color: isSuccess ? 'var(--r-green-default, #2abb7f)' : 'var(--r-red-default, #e34935)',
                        }}>
                          {isSuccess ? '\u2713 Success' : '\u2717 Failed'}
                        </span>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        ))
      )}
    </div>
  );
}
