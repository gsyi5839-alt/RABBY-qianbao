import React, { useState, useMemo, useCallback } from 'react';
import clsx from 'clsx';
import type { TokenItem } from '@rabby/shared';
import { Popup } from '../../../components/ui/Popup';
import { Input } from '../../../components/ui/Input';
import { Empty } from '../../../components/ui/Empty';
import { Loading } from '../../../components/ui/Loading';
import { formatTokenAmount, formatUsdValue } from '../../../utils';

interface TokenSelectorProps {
  visible: boolean;
  onClose: () => void;
  tokens: TokenItem[];
  selectedToken?: TokenItem | null;
  onSelect: (token: TokenItem) => void;
  isLoading?: boolean;
  className?: string;
}

const FALLBACK_ICON =
  'data:image/svg+xml,' +
  encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">' +
      '<circle cx="16" cy="16" r="16" fill="%23E0E5EC"/>' +
      '<text x="16" y="21" text-anchor="middle" font-size="14" fill="%236A7587">?</text></svg>'
  );

export const TokenSelector: React.FC<TokenSelectorProps> = ({
  visible,
  onClose,
  tokens,
  selectedToken,
  onSelect,
  isLoading = false,
  className,
}) => {
  const [search, setSearch] = useState('');

  const filteredTokens = useMemo(() => {
    if (!search.trim()) return tokens;
    const q = search.toLowerCase();
    return tokens.filter(
      (t) =>
        t.symbol.toLowerCase().includes(q) ||
        t.name.toLowerCase().includes(q) ||
        t.id.toLowerCase().includes(q)
    );
  }, [tokens, search]);

  const sortedTokens = useMemo(() => {
    return [...filteredTokens].sort(
      (a, b) => b.price * b.amount - a.price * a.amount
    );
  }, [filteredTokens]);

  const handleSelect = useCallback(
    (token: TokenItem) => {
      onSelect(token);
      onClose();
      setSearch('');
    },
    [onSelect, onClose]
  );

  const handleClose = useCallback(() => {
    onClose();
    setSearch('');
  }, [onClose]);

  return (
    <Popup
      visible={visible}
      onClose={handleClose}
      title="Select Token"
      height="70vh"
      className={className}
    >
      <div className="mb-3">
        <Input
          placeholder="Search name or paste address"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          prefix={<SearchIcon />}
        />
      </div>

      {isLoading ? (
        <div className="flex justify-center py-10">
          <Loading />
        </div>
      ) : sortedTokens.length === 0 ? (
        <Empty description="No tokens found" />
      ) : (
        <div className="flex flex-col gap-1">
          {sortedTokens.map((token) => {
            const value = token.price * token.amount;
            const isSelected =
              selectedToken?.id === token.id &&
              selectedToken?.chain === token.chain;

            return (
              <button
                key={`${token.chain}:${token.id}`}
                className={clsx(
                  'flex items-center gap-3 px-3 py-3 rounded-xl',
                  'transition-colors min-h-[56px]',
                  isSelected
                    ? 'bg-[var(--r-blue-light-1)]'
                    : 'hover:bg-[var(--r-neutral-bg-2)]'
                )}
                onClick={() => handleSelect(token)}
              >
                <img
                  src={token.logo_url || FALLBACK_ICON}
                  alt={token.symbol}
                  className="w-8 h-8 rounded-full flex-shrink-0"
                  onError={(e) => {
                    (e.target as HTMLImageElement).src = FALLBACK_ICON;
                  }}
                />
                <div className="flex flex-col items-start flex-1 min-w-0">
                  <span className="text-sm font-medium text-[var(--r-neutral-title-1)]">
                    {token.display_symbol || token.symbol}
                  </span>
                  <span className="text-xs text-[var(--r-neutral-foot)] truncate max-w-full">
                    {token.name}
                  </span>
                </div>
                <div className="flex flex-col items-end flex-shrink-0">
                  <span className="text-sm font-medium text-[var(--r-neutral-title-1)]">
                    {formatTokenAmount(token.amount)}
                  </span>
                  <span className="text-xs text-[var(--r-neutral-foot)]">
                    {formatUsdValue(value)}
                  </span>
                </div>
              </button>
            );
          })}
        </div>
      )}
    </Popup>
  );
};

const SearchIcon = () => (
  <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
    <circle cx="7" cy="7" r="5" stroke="currentColor" strokeWidth="1.5" />
    <path
      d="M11 11l3 3"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
    />
  </svg>
);
