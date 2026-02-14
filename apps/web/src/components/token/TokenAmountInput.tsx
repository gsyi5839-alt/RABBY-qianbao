import React, { useCallback } from 'react';
import clsx from 'clsx';
import type { TokenItem } from '@rabby/shared';

interface TokenAmountInputProps {
  token?: TokenItem | null;
  value: string;
  onChange: (value: string) => void;
  onTokenClick?: () => void;
  onMax?: () => void;
  usdValue?: string;
  disabled?: boolean;
  placeholder?: string;
  error?: string;
  className?: string;
}

const FALLBACK_ICON = 'data:image/svg+xml,' + encodeURIComponent(
  '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">' +
  '<circle cx="16" cy="16" r="16" fill="%23E0E5EC"/>' +
  '<text x="16" y="21" text-anchor="middle" font-size="14" fill="%236A7587">?</text></svg>'
);

export const TokenAmountInput: React.FC<TokenAmountInputProps> = ({
  token,
  value,
  onChange,
  onTokenClick,
  onMax,
  usdValue,
  disabled = false,
  placeholder = '0.00',
  error,
  className,
}) => {
  const handleInputChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const val = e.target.value;
      // Allow only valid number input
      if (val === '' || /^\d*\.?\d*$/.test(val)) {
        onChange(val);
      }
    },
    [onChange]
  );

  return (
    <div className={clsx('flex flex-col gap-1', className)}>
      <div
        className={clsx(
          'flex items-center gap-2 p-3 rounded-xl border transition-colors',
          'bg-[var(--r-neutral-bg-1)]',
          error
            ? 'border-[var(--r-red-default)]'
            : 'border-[var(--r-neutral-line)] focus-within:border-[var(--rabby-brand)]',
          disabled && 'opacity-50'
        )}
      >
        {/* Token selector */}
        <button
          className={clsx(
            'flex items-center gap-2 px-2 py-1.5 rounded-lg flex-shrink-0',
            'hover:bg-[var(--r-neutral-bg-2)] transition-colors',
            'min-h-[44px] min-w-[44px] -ml-1'
          )}
          onClick={onTokenClick}
          disabled={disabled}
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
            <span className="text-sm text-[var(--r-neutral-foot)]">
              Select
            </span>
          )}
          <svg width="12" height="12" viewBox="0 0 12 12" fill="none" className="text-[var(--r-neutral-foot)]">
            <path d="M3 4.5l3 3 3-3" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </button>

        {/* Amount input */}
        <div className="flex-1 flex flex-col items-end min-w-0">
          <input
            type="text"
            inputMode="decimal"
            value={value}
            onChange={handleInputChange}
            placeholder={placeholder}
            disabled={disabled}
            className={clsx(
              'w-full text-right text-lg font-semibold bg-transparent outline-none',
              'text-[var(--r-neutral-title-1)] placeholder:text-[var(--r-neutral-line)]'
            )}
          />
          <div className="flex items-center gap-2 mt-0.5">
            {usdValue && (
              <span className="text-xs text-[var(--r-neutral-foot)]">
                ~${usdValue}
              </span>
            )}
            {onMax && (
              <button
                onClick={onMax}
                disabled={disabled}
                className="text-xs font-medium text-[var(--rabby-brand)] hover:opacity-80 min-w-[44px] min-h-[28px]"
              >
                MAX
              </button>
            )}
          </div>
        </div>
      </div>
      {error && (
        <p className="text-xs text-[var(--r-red-default)]">{error}</p>
      )}
    </div>
  );
};
