import React, { useMemo } from 'react';
import clsx from 'clsx';
import type { BridgeQuoteItem } from '../hooks/useBridgeState';
import type { TokenItem } from '@rabby/shared';
import { formatTokenAmount, formatUsdValue } from '../../../utils';

const FALLBACK_ICON =
  'data:image/svg+xml,' +
  encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">' +
      '<circle cx="12" cy="12" r="12" fill="%23E0E5EC"/></svg>'
  );

interface BridgeQuoteListProps {
  quotes: BridgeQuoteItem[];
  loading: boolean;
  toToken: TokenItem | null;
  bestQuoteId: string | null;
  selectedQuoteId: string | null;
  onSelectQuote: (quote: BridgeQuoteItem) => void;
  className?: string;
}

export const BridgeQuoteList: React.FC<BridgeQuoteListProps> = ({
  quotes,
  loading,
  toToken,
  bestQuoteId,
  selectedQuoteId,
  onSelectQuote,
  className,
}) => {
  const sortedQuotes = useMemo(() => {
    return [...quotes].sort(
      (a, b) => (b.to_token_amount || 0) - (a.to_token_amount || 0)
    );
  }, [quotes]);

  if (!quotes.length && !loading) return null;

  return (
    <div className={clsx('flex flex-col gap-2', className)}>
      <div className="flex items-center justify-between px-1">
        <span className="text-xs font-medium text-[var(--r-neutral-foot)]">
          Bridge Routes
        </span>
        {loading && (
          <span className="text-xs text-[var(--r-neutral-foot)]">
            Loading...
          </span>
        )}
      </div>
      <div className="flex flex-col gap-2">
        {sortedQuotes.map((quote) => {
          const quoteId = `${quote.aggregator.id}-${quote.bridge_id}`;
          return (
            <BridgeQuoteCard
              key={quoteId}
              quote={quote}
              toToken={toToken}
              isBest={quoteId === bestQuoteId}
              isSelected={quoteId === (selectedQuoteId || bestQuoteId)}
              onSelect={() => onSelectQuote(quote)}
            />
          );
        })}
        {loading &&
          !sortedQuotes.length &&
          Array.from({ length: 3 }).map((_, i) => (
            <div
              key={i}
              className="h-20 rounded-xl bg-[var(--r-neutral-bg-1)] animate-pulse"
            />
          ))}
      </div>
    </div>
  );
};

interface BridgeQuoteCardProps {
  quote: BridgeQuoteItem;
  toToken: TokenItem | null;
  isBest: boolean;
  isSelected: boolean;
  onSelect: () => void;
}

const BridgeQuoteCard: React.FC<BridgeQuoteCardProps> = ({
  quote,
  toToken,
  isBest,
  isSelected,
  onSelect,
}) => {
  const receiveAmount = useMemo(() => {
    if (!toToken) return '0';
    return formatTokenAmount(quote.to_token_amount);
  }, [quote, toToken]);

  const gasFee = useMemo(() => {
    return formatUsdValue(quote.gas_fee?.usd_value || 0);
  }, [quote]);

  const duration = useMemo(() => {
    if (!quote.duration) return '--';
    if (quote.duration < 60) return `~${quote.duration}s`;
    const mins = Math.ceil(quote.duration / 60);
    return `~${mins} min`;
  }, [quote.duration]);

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
      {/* Bridge logo */}
      <img
        src={quote.bridge?.logo_url || quote.aggregator?.logo_url || FALLBACK_ICON}
        alt={quote.bridge?.name || quote.aggregator?.name || ''}
        className="w-8 h-8 rounded-full flex-shrink-0"
        onError={(e) => {
          (e.target as HTMLImageElement).src = FALLBACK_ICON;
        }}
      />

      {/* Info */}
      <div className="flex-1 min-w-0 text-left">
        <div className="flex items-center gap-2">
          <span className="text-sm font-medium text-[var(--r-neutral-title-1)] truncate">
            {quote.bridge?.name || quote.aggregator?.name || 'Bridge'}
          </span>
          {isBest && (
            <span className="text-[10px] px-1.5 py-0.5 rounded bg-[var(--r-green-light)] text-[var(--r-green-default)] font-medium flex-shrink-0">
              Best
            </span>
          )}
        </div>
        <div className="flex items-center gap-2 mt-0.5">
          <span className="text-xs text-[var(--r-neutral-foot)]">
            Gas: {gasFee}
          </span>
          <span className="text-xs text-[var(--r-neutral-foot)]">
            {duration}
          </span>
        </div>
      </div>

      {/* Receive amount */}
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
