import React, { useMemo } from 'react';
import type { ChainBalance } from '../../../store/balance';
import { useCurrentBalance } from '../../../hooks';
import { useChain } from '../../../hooks';
import { ChainIcon } from '../../../components/chain';
import { formatUsdValue } from '../../../utils';

interface ChainBalanceBarProps {
  activeChain?: string;
  onChainClick?: (chainServerId: string) => void;
}

const styles = {
  container: {
    display: 'flex',
    flexDirection: 'column',
    gap: '8px',
  } as React.CSSProperties,
  header: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
  } as React.CSSProperties,
  title: {
    fontSize: 14,
    fontWeight: 600,
    color: 'var(--r-neutral-title-1)',
  } as React.CSSProperties,
  scrollContainer: {
    display: 'flex',
    gap: '8px',
    overflowX: 'auto',
    paddingBottom: 4,
    scrollbarWidth: 'none',
    msOverflowStyle: 'none',
    WebkitOverflowScrolling: 'touch',
  } as React.CSSProperties,
  chainItem: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    gap: '6px',
    padding: '10px 12px',
    borderRadius: 12,
    cursor: 'pointer',
    flexShrink: 0,
    minWidth: 72,
    transition: 'background 0.15s, border-color 0.15s',
    border: '1.5px solid transparent',
  } as React.CSSProperties,
  chainName: {
    fontSize: 11,
    fontWeight: 500,
    whiteSpace: 'nowrap',
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    maxWidth: 60,
    textAlign: 'center',
  } as React.CSSProperties,
  chainBalance: {
    fontSize: 11,
    fontWeight: 600,
    whiteSpace: 'nowrap',
  } as React.CSSProperties,
  emptyState: {
    padding: '16px',
    textAlign: 'center',
    fontSize: 13,
    color: 'var(--r-neutral-foot)',
    background: 'var(--r-neutral-card-1)',
    borderRadius: 12,
  } as React.CSSProperties,
  percentBar: {
    width: '100%',
    height: 4,
    borderRadius: 2,
    overflow: 'hidden',
    display: 'flex',
    background: 'var(--r-neutral-line)',
  } as React.CSSProperties,
};

/** Colors assigned to chain segments */
const CHAIN_COLORS = [
  '#627EEA', // Ethereum blue
  '#F0B90B', // BSC yellow
  '#8247E5', // Polygon purple
  '#FF4040', // Avalanche red
  '#2D73FF', // Arbitrum blue
  '#FF0420', // Optimism red
  '#00D395', // Fantom teal
  '#1B6CB0', // Cronos
  '#E6007A', // Moonbeam pink
  '#6B8CEF', // Other
];

function getChainColor(index: number): string {
  return CHAIN_COLORS[index % CHAIN_COLORS.length];
}

export const ChainBalanceBar: React.FC<ChainBalanceBarProps> = ({
  activeChain,
  onChainClick,
}) => {
  const { matteredChainBalances } = useCurrentBalance();
  const { chainList } = useChain();

  const sortedBalances = useMemo(() => {
    const items = [...matteredChainBalances];
    items.sort((a, b) => b.usdValue - a.usdValue);
    return items;
  }, [matteredChainBalances]);

  const chainMap = useMemo(() => {
    const map = new Map<string, typeof chainList[0]>();
    chainList.forEach((c) => {
      map.set(c.serverId, c);
      map.set(c.enum, c);
      map.set(c.name, c);
    });
    return map;
  }, [chainList]);

  const findChainForBalance = (cb: ChainBalance) => {
    return chainMap.get(cb.id) || chainMap.get(cb.name) || null;
  };

  if (sortedBalances.length === 0) {
    return null;
  }

  const totalUsd = sortedBalances.reduce((acc, cb) => acc + cb.usdValue, 0);

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <span style={styles.title}>Chain Balance</span>
        {activeChain && (
          <button
            style={{
              border: 'none',
              background: 'transparent',
              color: 'var(--rabby-brand)',
              fontSize: 12,
              fontWeight: 500,
              cursor: 'pointer',
              padding: 0,
            }}
            onClick={() => onChainClick?.('')}
          >
            Show all
          </button>
        )}
      </div>

      {/* Percentage bar */}
      {totalUsd > 0 && (
        <div style={styles.percentBar}>
          {sortedBalances.map((cb, idx) => {
            const pct = (cb.usdValue / totalUsd) * 100;
            if (pct < 0.5) return null;
            return (
              <div
                key={cb.id}
                style={{
                  width: `${pct}%`,
                  height: '100%',
                  background: getChainColor(idx),
                  transition: 'width 0.3s',
                }}
              />
            );
          })}
        </div>
      )}

      {/* Scrollable chain items */}
      <div style={styles.scrollContainer}>
        {sortedBalances.map((cb, idx) => {
          const chain = findChainForBalance(cb);
          const isActive = activeChain === cb.id;

          return (
            <div
              key={cb.id}
              style={{
                ...styles.chainItem,
                background: isActive
                  ? 'var(--rabby-brand-light)'
                  : 'var(--r-neutral-bg-2)',
                borderColor: isActive
                  ? 'var(--rabby-brand)'
                  : 'transparent',
              }}
              onClick={() => onChainClick?.(cb.id)}
              role="button"
              tabIndex={0}
            >
              <ChainIcon chain={chain} size="sm" />
              <span
                style={{
                  ...styles.chainName,
                  color: isActive
                    ? 'var(--rabby-brand)'
                    : 'var(--r-neutral-body)',
                }}
              >
                {cb.name}
              </span>
              <span
                style={{
                  ...styles.chainBalance,
                  color: isActive
                    ? 'var(--rabby-brand)'
                    : 'var(--r-neutral-title-1)',
                }}
              >
                {formatUsdValue(cb.usdValue)}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
};
