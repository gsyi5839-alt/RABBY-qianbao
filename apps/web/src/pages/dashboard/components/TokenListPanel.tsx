import React, { useCallback, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import type { TokenItem } from '@rabby/shared';
import { useTokenList } from '../../../hooks';
import type { TokenSortField, TokenSortOrder } from '../../../hooks';
import { useChain } from '../../../hooks';
import { TokenWithChain } from '../../../components/token';
import { Empty } from '../../../components/ui';
import { formatTokenAmount, formatUsdValue } from '../../../utils';

interface TokenListPanelProps {
  chainFilter?: string;
  onTokenClick?: (token: TokenItem) => void;
}

const SMALL_BALANCE_THRESHOLD = 1; // $1

const sortOptions: { label: string; value: TokenSortField }[] = [
  { label: 'Value', value: 'value' },
  { label: 'Amount', value: 'amount' },
  { label: 'Name', value: 'name' },
];

const styles = {
  container: {
    display: 'flex',
    flexDirection: 'column',
    gap: '0',
  } as React.CSSProperties,
  header: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 12,
  } as React.CSSProperties,
  title: {
    fontSize: 16,
    fontWeight: 600,
    color: 'var(--r-neutral-title-1)',
  } as React.CSSProperties,
  controls: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
  } as React.CSSProperties,
  searchBox: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    padding: '8px 12px',
    borderRadius: 12,
    border: '1px solid var(--r-neutral-line)',
    background: 'var(--r-neutral-bg-1)',
    marginBottom: 8,
  } as React.CSSProperties,
  searchInput: {
    flex: 1,
    border: 'none',
    background: 'transparent',
    fontSize: 14,
    color: 'var(--r-neutral-title-1)',
    outline: 'none',
    minWidth: 0,
  } as React.CSSProperties,
  sortBar: {
    display: 'flex',
    alignItems: 'center',
    gap: '4px',
    marginBottom: 8,
  } as React.CSSProperties,
  sortBtn: {
    padding: '4px 10px',
    borderRadius: 8,
    border: 'none',
    fontSize: 12,
    fontWeight: 500,
    cursor: 'pointer',
  } as React.CSSProperties,
  toggleRow: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 8,
  } as React.CSSProperties,
  toggleLabel: {
    fontSize: 12,
    color: 'var(--r-neutral-foot)',
  } as React.CSSProperties,
  toggleBtn: {
    width: 36,
    height: 20,
    borderRadius: 10,
    border: 'none',
    cursor: 'pointer',
    position: 'relative',
    transition: 'background 0.2s',
    padding: 0,
  } as React.CSSProperties,
  toggleKnob: {
    position: 'absolute',
    top: 2,
    width: 16,
    height: 16,
    borderRadius: '50%',
    background: '#fff',
    transition: 'left 0.2s',
    boxShadow: '0 1px 3px rgba(0,0,0,0.15)',
  } as React.CSSProperties,
  list: {
    background: 'var(--r-neutral-card-1)',
    borderRadius: 16,
    boxShadow: 'var(--rabby-shadow-sm)',
    overflow: 'hidden',
  } as React.CSSProperties,
  tokenRow: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    padding: '12px 16px',
    cursor: 'pointer',
    borderBottom: '1px solid var(--r-neutral-line)',
    transition: 'background 0.15s',
  } as React.CSSProperties,
  tokenInfo: {
    display: 'flex',
    flexDirection: 'column',
    gap: '2px',
    flex: 1,
    minWidth: 0,
  } as React.CSSProperties,
  tokenName: {
    fontSize: 14,
    fontWeight: 500,
    color: 'var(--r-neutral-title-1)',
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap',
  } as React.CSSProperties,
  tokenSymbol: {
    fontSize: 12,
    color: 'var(--r-neutral-foot)',
  } as React.CSSProperties,
  tokenValues: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'flex-end',
    gap: '2px',
    flexShrink: 0,
  } as React.CSSProperties,
  tokenUsd: {
    fontSize: 14,
    fontWeight: 600,
    color: 'var(--r-neutral-title-1)',
  } as React.CSSProperties,
  tokenAmount: {
    fontSize: 12,
    color: 'var(--r-neutral-foot)',
  } as React.CSSProperties,
  addBtn: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: '6px',
    padding: '12px 16px',
    cursor: 'pointer',
    color: 'var(--rabby-brand)',
    fontSize: 14,
    fontWeight: 500,
    border: 'none',
    background: 'transparent',
    width: '100%',
  } as React.CSSProperties,
};

export const TokenListPanel: React.FC<TokenListPanelProps> = ({
  chainFilter,
  onTokenClick,
}) => {
  const navigate = useNavigate();
  const { chainList } = useChain();

  const [sortBy, setSortBy] = useState<TokenSortField>('value');
  const [sortOrder] = useState<TokenSortOrder>('desc');
  const [hideSmall, setHideSmall] = useState(false);
  const [showSearch, setShowSearch] = useState(false);

  const {
    searchResults,
    searchKeyword,
    setSearchKeyword,
    isLoading,
  } = useTokenList({
    chainServerId: chainFilter,
    withBalance: true,
    sortBy,
    sortOrder,
  });

  const displayTokens = useMemo(() => {
    let tokens = searchResults;
    if (hideSmall) {
      tokens = tokens.filter(
        (t) => t.price * t.amount >= SMALL_BALANCE_THRESHOLD
      );
    }
    return tokens;
  }, [searchResults, hideSmall]);

  const handleTokenClick = useCallback(
    (token: TokenItem) => {
      if (onTokenClick) {
        onTokenClick(token);
      } else {
        navigate(`/token-detail?id=${token.id}&chain=${token.chain}`);
      }
    },
    [onTokenClick, navigate]
  );

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <span style={styles.title}>Tokens</span>
        <div style={styles.controls}>
          <button
            style={{
              ...styles.sortBtn,
              background: 'transparent',
              color: 'var(--rabby-brand)',
              padding: '4px 8px',
            }}
            onClick={() => setShowSearch(!showSearch)}
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
              <circle cx="11" cy="11" r="8" />
              <line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
          </button>
        </div>
      </div>

      {showSearch && (
        <div style={styles.searchBox}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--r-neutral-foot)" strokeWidth={2}>
            <circle cx="11" cy="11" r="8" />
            <line x1="21" y1="21" x2="16.65" y2="16.65" />
          </svg>
          <input
            style={styles.searchInput}
            placeholder="Search tokens..."
            value={searchKeyword}
            onChange={(e) => setSearchKeyword(e.target.value)}
            autoFocus
          />
          {searchKeyword && (
            <button
              style={{ border: 'none', background: 'transparent', cursor: 'pointer', padding: 0 }}
              onClick={() => setSearchKeyword('')}
            >
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--r-neutral-foot)" strokeWidth={2}>
                <line x1="18" y1="6" x2="6" y2="18" />
                <line x1="6" y1="6" x2="18" y2="18" />
              </svg>
            </button>
          )}
        </div>
      )}

      <div style={styles.sortBar}>
        {sortOptions.map((opt) => (
          <button
            key={opt.value}
            style={{
              ...styles.sortBtn,
              background: sortBy === opt.value ? 'var(--rabby-brand)' : 'var(--r-neutral-bg-2)',
              color: sortBy === opt.value ? '#fff' : 'var(--r-neutral-foot)',
            }}
            onClick={() => setSortBy(opt.value)}
          >
            {opt.label}
          </button>
        ))}
        <div style={{ flex: 1 }} />
        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
          <span style={styles.toggleLabel}>Hide small</span>
          <button
            style={{
              ...styles.toggleBtn,
              background: hideSmall ? 'var(--rabby-brand)' : 'var(--r-neutral-line)',
            }}
            onClick={() => setHideSmall(!hideSmall)}
          >
            <div
              style={{
                ...styles.toggleKnob,
                left: hideSmall ? 18 : 2,
              }}
            />
          </button>
        </div>
      </div>

      <div style={styles.list}>
        {isLoading && displayTokens.length === 0 ? (
          <div style={{ padding: '40px 16px', textAlign: 'center' }}>
            <span style={{ color: 'var(--r-neutral-foot)', fontSize: 14 }}>
              Loading tokens...
            </span>
          </div>
        ) : displayTokens.length === 0 ? (
          <Empty
            description={
              searchKeyword
                ? 'No tokens match your search'
                : 'No tokens yet'
            }
          />
        ) : (
          displayTokens.map((token, idx) => (
            <div
              key={`${token.chain}-${token.id}-${idx}`}
              style={{
                ...styles.tokenRow,
                borderBottom:
                  idx === displayTokens.length - 1
                    ? 'none'
                    : styles.tokenRow.borderBottom,
              }}
              onClick={() => handleTokenClick(token)}
            >
              <TokenWithChain
                token={token}
                chains={chainList}
                width="36px"
                height="36px"
                chainSize={16}
              />
              <div style={styles.tokenInfo}>
                <span style={styles.tokenName}>
                  {token.display_symbol || token.symbol}
                </span>
                <span style={styles.tokenSymbol}>{token.name}</span>
              </div>
              <div style={styles.tokenValues}>
                <span style={styles.tokenUsd}>
                  {formatUsdValue(token.price * token.amount)}
                </span>
                <span style={styles.tokenAmount}>
                  {formatTokenAmount(token.amount)} {token.symbol}
                </span>
              </div>
            </div>
          ))
        )}

        <button
          style={styles.addBtn}
          onClick={() => navigate('/custom-token')}
        >
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
            <line x1="12" y1="5" x2="12" y2="19" />
            <line x1="5" y1="12" x2="19" y2="12" />
          </svg>
          Add Custom Token
        </button>
      </div>
    </div>
  );
};
