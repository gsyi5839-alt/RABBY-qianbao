import React, { useMemo } from 'react';
import clsx from 'clsx';
import type { DexQuoteItem } from '../hooks/useSwapState';
import type { TokenItem } from '@rabby/shared';
import { formatTokenAmount, formatUsdValue } from '../../../utils';

const FALLBACK_ICON =
  'data:image/svg+xml,' +
  encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">' +
      '<circle cx="12" cy="12" r="12" fill="%23E0E5EC"/></svg>'
  );

interface QuoteListProps {
  quotes: DexQuoteItem[];
  loading: boolean;
  toToken: TokenItem | null;
  bestDexId: string | null;
  selectedDex: string | null;
  onSelectDex: (dexId: string) => void;
  className?: string;
}

export const QuoteList: React.FC<QuoteListProps> = ({
  quotes,
  loading,
  toToken,
  bestDexId,
  selectedDex,
  onSelectDex,
  className,
}) => {
  const sortedQuotes = useMemo(() => {
    return [...quotes].sort((a, b) => {
      const aAmt = a.quote?.receive_token_raw_amount || 0;
      const bAmt = b.quote?.receive_token_raw_amount || 0;
      return bAmt - aAmt;
    });
  }, [quotes]);

  if (!quotes.length && !loading) return null;

  return (
    <div className={clsx('flex flex-col gap-2', className)}>
      <div className="flex items-center justify-between px-1">
        <span className="text-xs font-medium text-[var(--r-neutral-foot)]">
          Quotes
        </span>
        {loading && (
          <span className="text-xs text-[var(--r-neutral-foot)]">
            Loading...
          </span>
        )}
      </div>
      <div className="flex flex-col gap-2">
        {sortedQuotes.map((item) => (
          <QuoteItem
            key={item.dex.id}
            item={item}
            toToken={toToken}
            isBest={item.dex.id === bestDexId}
            isSelected={item.dex.id === (selectedDex || bestDexId)}
            onSelect={() => onSelectDex(item.dex.id)}
          />
        ))}
        {loading &&
          !sortedQuotes.length &&
          Array.from({ length: 3 }).map((_, i) => (
            <div
              key={i}
              className="h-16 rounded-xl bg-[var(--r-neutral-bg-1)] animate-pulse"
            />
          ))}
      </div>
    </div>
  );
};

interface QuoteItemProps {
  item: DexQuoteItem;
  toToken: TokenItem | null;
  isBest: boolean;
  isSelected: boolean;
  onSelect: () => void;
}

const QuoteItem: React.FC<QuoteItemProps> = ({
  item,
  toToken,
  isBest,
  isSelected,
  onSelect,
}) => {
  const receiveAmount = useMemo(() => {
    if (!item.quote || !toToken) return '0';
    const amount =
      item.quote.receive_token_raw_amount / Math.pow(10, toToken.decimals);
    return formatTokenAmount(amount);
  }, [item.quote, toToken]);

  const gasUsd = useMemo(() => {
    if (!item.quote?.gas) return '--';
    return formatUsdValue(item.quote.gas.gas_cost_usd_value);
  }, [item.quote]);

  if (item.loading) {
    return (
      <div className="flex items-center gap-3 p-3 rounded-xl bg-[var(--r-neutral-bg-1)]">
        <div className="w-8 h-8 rounded-full bg-[var(--r-neutral-line)] animate-pulse" />
        <div className="flex-1">
          <div className="h-4 w-20 bg-[var(--r-neutral-line)] rounded animate-pulse mb-1" />
          <div className="h-3 w-14 bg-[var(--r-neutral-line)] rounded animate-pulse" />
        </div>
      </div>
    );
  }

  if (item.error || !item.quote) {
    return (
      <div className="flex items-center gap-3 p-3 rounded-xl bg-[var(--r-neutral-bg-1)] opacity-50">
        <img
          src={item.dex.logo_url || FALLBACK_ICON}
          alt={item.dex.name}
          className="w-8 h-8 rounded-full"
          onError={(e) => {
            (e.target as HTMLImageElement).src = FALLBACK_ICON;
          }}
        />
        <div className="flex-1 min-w-0">
          <span className="text-sm font-medium text-[var(--r-neutral-title-1)]">
            {item.dex.name}
          </span>
          <p className="text-xs text-[var(--r-red-default)]">No quote</p>
        </div>
      </div>
    );
  }

  return (
    <button
      onClick={onSelect}
      className={clsx(
        'flex items-center gap-3 p-3 rounded-xl transition-colors min-h-[44px]',
        'bg-[var(--r-neutral-bg-1)]',
        isSelected
          ? 'ring-2 ring-[var(--rabby-brand)]'
          : 'hover:bg-[var(--r-neutral-bg-2)]'
      )}
    >
      <img
        src={item.dex.logo_url || FALLBACK_ICON}
        alt={item.dex.name}
        className="w-8 h-8 rounded-full flex-shrink-0"
        onError={(e) => {
          (e.target as HTMLImageElement).src = FALLBACK_ICON;
        }}
      />

      <div className="flex-1 min-w-0 text-left">
        <div className="flex items-center gap-2">
          <span className="text-sm font-medium text-[var(--r-neutral-title-1)] truncate">
            {item.dex.name}
          </span>
          {isBest && (
            <span className="text-[10px] px-1.5 py-0.5 rounded bg-[var(--r-green-light)] text-[var(--r-green-default)] font-medium flex-shrink-0">
              Best
            </span>
          )}
        </div>
        <span className="text-xs text-[var(--r-neutral-foot)]">
          Gas: {gasUsd}
        </span>
      </div>

      <div className="text-right flex-shrink-0">
        <p className="text-sm font-semibold text-[var(--r-neutral-title-1)]">
          {receiveAmount}
        </p>
        <p className="text-xs text-[var(--r-neutral-foot)]">
          {toToken?.display_symbol || toToken?.symbol || ''}
        </p>
      </div>
    </button>
  );
};
