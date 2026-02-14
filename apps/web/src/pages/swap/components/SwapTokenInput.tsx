import React, { useCallback, useMemo } from 'react';
import clsx from 'clsx';
import type { TokenItem } from '@rabby/shared';
import { formatTokenAmount, formatUsdValue } from '../../../utils';

const FALLBACK_ICON =
  'data:image/svg+xml,' +
  encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">' +
      '<circle cx="16" cy="16" r="16" fill="%23E0E5EC"/>' +
      '<text x="16" y="21" text-anchor="middle" font-size="14" fill="%236A7587">?</text></svg>'
  );

interface SwapTokenInputProps {
  type: 'from' | 'to';
  token: TokenItem | null;
  value: string;
  onValueChange?: (value: string) => void;
  onTokenClick?: () => void;
  onMax?: () => void;
  loading?: boolean;
  insufficient?: boolean;
  className?: string;
}

export const SwapTokenInput: React.FC<SwapTokenInputProps> = ({
  type,
  token,
  value,
  onValueChange,
  onTokenClick,
  onMax,
  loading = false,
  insufficient = false,
  className,
}) => {
  const isFrom = type === 'from';

  const handleChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const val = e.target.value;
      if (val === '' || /^\d*\.?\d*$/.test(val)) {
        onValueChange?.(val);
      }
    },
    [onValueChange]
  );

  const balance = useMemo(() => {
    if (!token) return '0';
    return formatTokenAmount(token.amount || 0);
  }, [token]);

  const usdValue = useMemo(() => {
    if (!token || !value) return formatUsdValue(0);
    return formatUsdValue(parseFloat(value || '0') * (token.price || 0));
  }, [token, value]);

  return (
    <div
      className={clsx(
        'p-4 rounded-xl bg-[var(--r-neutral-bg-1)]',
        className
      )}
    >
      {/* Label row */}
      <div className="flex items-center justify-between mb-2">
        <span className="text-xs text-[var(--r-neutral-foot)]">
          {isFrom ? 'From' : 'To'}
        </span>
        {isFrom && token && (
          <div className="flex items-center gap-1">
            <span className="text-xs text-[var(--r-neutral-foot)]">
              Balance: {balance}
            </span>
            {onMax && (
              <button
                onClick={onMax}
                className="text-xs font-medium text-[var(--rabby-brand)] ml-1 min-w-[44px] min-h-[28px]"
              >
                MAX
              </button>
            )}
          </div>
        )}
      </div>

      {/* Token + Amount row */}
      <div className="flex items-center gap-3">
        <button
          onClick={onTokenClick}
          className={clsx(
            'flex items-center gap-2 px-3 py-2 rounded-xl flex-shrink-0',
            'bg-[var(--r-neutral-bg-2)] hover:bg-[var(--r-neutral-line)]',
            'transition-colors min-h-[44px]'
          )}
        >
          {token ? (
            <>
              <img
                src={token.logo_url || FALLBACK_ICON}
                alt={token.symbol}
                className="w-6 h-6 rounded-full"
                onError={(e) => {
                  (e.target as HTMLImageElement).src = FALLBACK_ICON;
                }}
              />
              <span className="text-sm font-semibold text-[var(--r-neutral-title-1)] whitespace-nowrap">
                {token.display_symbol || token.symbol}
              </span>
            </>
          ) : (
            <span className="text-sm text-[var(--r-neutral-foot)]">Select</span>
          )}
          <svg
            width="12"
            height="12"
            viewBox="0 0 12 12"
            fill="none"
            className="text-[var(--r-neutral-foot)]"
          >
            <path
              d="M3 4.5l3 3 3-3"
              stroke="currentColor"
              strokeWidth="1.2"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </button>

        <div className="flex-1 flex flex-col items-end min-w-0">
          {loading ? (
            <div className="h-7 w-24 bg-[var(--r-neutral-line)] rounded animate-pulse" />
          ) : (
            <input
              type="text"
              inputMode="decimal"
              value={value}
              onChange={isFrom ? handleChange : undefined}
              readOnly={!isFrom}
              placeholder="0"
              className={clsx(
                'w-full text-right text-xl font-semibold bg-transparent outline-none',
                'text-[var(--r-neutral-title-1)] placeholder:text-[var(--r-neutral-line)]',
                insufficient && isFrom && 'text-[var(--r-red-default)]'
              )}
            />
          )}
          <span className="text-xs text-[var(--r-neutral-foot)] mt-0.5">
            {usdValue}
          </span>
        </div>
      </div>
    </div>
  );
};
