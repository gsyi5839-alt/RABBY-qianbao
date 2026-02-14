import React, { useCallback, useMemo, useState } from 'react';
import { useChain } from '../../../hooks';
import { formatGasPrice } from '../../../utils';

interface GasPriceBarProps {
  gasPrice?: number;
  isLoading?: boolean;
}

/** Classify gas price level based on Gwei thresholds */
function getGasLevel(gweiPrice: number): 'low' | 'medium' | 'high' {
  if (gweiPrice <= 20) return 'low';
  if (gweiPrice <= 80) return 'medium';
  return 'high';
}

const levelConfig = {
  low: {
    color: 'var(--r-green-default)',
    label: 'Low',
    bgColor: 'rgba(22, 199, 132, 0.08)',
  },
  medium: {
    color: '#F0B90B',
    label: 'Medium',
    bgColor: 'rgba(240, 185, 11, 0.08)',
  },
  high: {
    color: 'var(--r-red-default)',
    label: 'High',
    bgColor: 'rgba(234, 57, 67, 0.08)',
  },
};

const styles = {
  container: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: '12px 16px',
    background: 'var(--r-neutral-card-1)',
    borderRadius: 12,
    boxShadow: 'var(--rabby-shadow-sm)',
    cursor: 'pointer',
    transition: 'background 0.15s',
  } as React.CSSProperties,
  left: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
  } as React.CSSProperties,
  dot: {
    width: 8,
    height: 8,
    borderRadius: '50%',
  } as React.CSSProperties,
  label: {
    fontSize: 13,
    color: 'var(--r-neutral-body)',
  } as React.CSSProperties,
  right: {
    display: 'flex',
    alignItems: 'center',
    gap: '6px',
  } as React.CSSProperties,
  value: {
    fontSize: 14,
    fontWeight: 600,
    color: 'var(--r-neutral-title-1)',
  } as React.CSSProperties,
  unit: {
    fontSize: 12,
    color: 'var(--r-neutral-foot)',
  } as React.CSSProperties,
  levelBadge: {
    fontSize: 11,
    fontWeight: 600,
    padding: '2px 8px',
    borderRadius: 6,
  } as React.CSSProperties,
  expanded: {
    marginTop: 12,
    paddingTop: 12,
    borderTop: '1px solid var(--r-neutral-line)',
    display: 'flex',
    flexDirection: 'column',
    gap: '8px',
  } as React.CSSProperties,
  expandedRow: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    fontSize: 13,
  } as React.CSSProperties,
  chainName: {
    display: 'flex',
    alignItems: 'center',
    gap: '4px',
    color: 'var(--r-neutral-body)',
  } as React.CSSProperties,
  expandedValue: {
    fontWeight: 500,
    color: 'var(--r-neutral-title-1)',
  } as React.CSSProperties,
};

export const GasPriceBar: React.FC<GasPriceBarProps> = ({
  gasPrice = 0,
  isLoading = false,
}) => {
  const { currentChainInfo } = useChain();
  const [expanded, setExpanded] = useState(false);

  const gweiValue = useMemo(() => {
    if (!gasPrice) return 0;
    // If gasPrice is already in Gwei (small number), use as-is
    // If gasPrice is in Wei (large number), convert
    if (gasPrice > 1e6) {
      return gasPrice / 1e9;
    }
    return gasPrice;
  }, [gasPrice]);

  const level = useMemo(() => getGasLevel(gweiValue), [gweiValue]);
  const config = levelConfig[level];

  const displayGwei = useMemo(() => {
    if (isLoading || !gasPrice) return '--';
    if (gweiValue < 0.01 && gweiValue > 0) return '< 0.01';
    return gweiValue.toFixed(gweiValue >= 100 ? 0 : 2).replace(/\.?0+$/, '');
  }, [gasPrice, gweiValue, isLoading]);

  const chainName = currentChainInfo?.name || 'Ethereum';

  const handleToggle = useCallback(() => {
    setExpanded((prev) => !prev);
  }, []);

  return (
    <div>
      <div style={styles.container} onClick={handleToggle}>
        <div style={styles.left}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={config.color} strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
            <path d="M17.657 18.657A8 8 0 016.343 7.343S7 9 9 10c0-2 .5-5 2.986-7C14 5 16.09 5.777 17.656 7.343A7.975 7.975 0 0120 13a7.975 7.975 0 01-2.343 5.657z" />
          </svg>
          <span style={styles.label}>Gas ({chainName})</span>
        </div>
        <div style={styles.right}>
          <span
            style={{
              ...styles.levelBadge,
              color: config.color,
              background: config.bgColor,
            }}
          >
            {config.label}
          </span>
          <span style={styles.value}>{displayGwei}</span>
          <span style={styles.unit}>Gwei</span>
          <svg
            width="14"
            height="14"
            viewBox="0 0 24 24"
            fill="none"
            stroke="var(--r-neutral-foot)"
            strokeWidth={2}
            style={{
              transform: expanded ? 'rotate(180deg)' : 'rotate(0deg)',
              transition: 'transform 0.2s',
            }}
          >
            <polyline points="6 9 12 15 18 9" />
          </svg>
        </div>
      </div>

      {expanded && (
        <div style={{ ...styles.container, marginTop: 0, borderRadius: '0 0 12px 12px', paddingTop: 0 }}>
          <div style={{ ...styles.expanded, width: '100%' }}>
            <div style={styles.expandedRow}>
              <span style={styles.chainName}>
                <span
                  style={{
                    ...styles.dot,
                    background: levelConfig.low.color,
                  }}
                />
                Slow
              </span>
              <span style={styles.expandedValue}>
                {gasPrice ? `${Math.max(1, Math.round(gweiValue * 0.8))} Gwei` : '-- Gwei'}
              </span>
            </div>
            <div style={styles.expandedRow}>
              <span style={styles.chainName}>
                <span
                  style={{
                    ...styles.dot,
                    background: levelConfig.medium.color,
                  }}
                />
                Standard
              </span>
              <span style={styles.expandedValue}>
                {gasPrice ? `${Math.round(gweiValue)} Gwei` : '-- Gwei'}
              </span>
            </div>
            <div style={styles.expandedRow}>
              <span style={styles.chainName}>
                <span
                  style={{
                    ...styles.dot,
                    background: levelConfig.high.color,
                  }}
                />
                Fast
              </span>
              <span style={styles.expandedValue}>
                {gasPrice ? `${Math.round(gweiValue * 1.3)} Gwei` : '-- Gwei'}
              </span>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
