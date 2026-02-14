import React, { useState, useCallback, useRef, useEffect } from 'react';
import clsx from 'clsx';
import { isValidAddress, ellipsisAddress } from '../../../utils';

interface AddressInputProps {
  value: string;
  onChange: (value: string) => void;
  onSelectClick?: () => void;
  error?: string;
  disabled?: boolean;
  className?: string;
}

export const AddressInput: React.FC<AddressInputProps> = ({
  value,
  onChange,
  onSelectClick,
  error,
  disabled = false,
  className,
}) => {
  const [isFocused, setIsFocused] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  const handleChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      onChange(e.target.value.trim());
    },
    [onChange]
  );

  const handlePaste = useCallback(async () => {
    try {
      const text = await navigator.clipboard.readText();
      if (text) {
        onChange(text.trim());
      }
    } catch {
      // Clipboard API not available or permission denied
    }
  }, [onChange]);

  const handleClear = useCallback(() => {
    onChange('');
    inputRef.current?.focus();
  }, [onChange]);

  const isValid = value ? isValidAddress(value) : true;
  const showCompact = value && isValid && !isFocused;

  return (
    <div className={clsx('flex flex-col gap-1', className)}>
      <div className="flex items-center justify-between mb-1">
        <span className="text-xs font-medium text-[var(--r-neutral-body)]">
          To
        </span>
        {onSelectClick && (
          <button
            className="text-xs font-medium text-[var(--rabby-brand)]
              min-w-[44px] min-h-[28px] flex items-center justify-center"
            onClick={onSelectClick}
          >
            <ContactBookIcon />
            <span className="ml-1">Contacts</span>
          </button>
        )}
      </div>
      <div
        className={clsx(
          'flex items-center gap-2 px-3 h-12 rounded-xl border transition-colors',
          'bg-[var(--r-neutral-bg-1)]',
          error || (!isValid && value)
            ? 'border-[var(--r-red-default)]'
            : isFocused
            ? 'border-[var(--rabby-brand)]'
            : 'border-[var(--r-neutral-line)]',
          disabled && 'opacity-50'
        )}
      >
        {showCompact ? (
          <button
            className="flex-1 text-left text-sm text-[var(--r-neutral-title-1)] font-mono min-h-[44px] flex items-center"
            onClick={() => {
              setIsFocused(true);
              setTimeout(() => inputRef.current?.focus(), 0);
            }}
          >
            {ellipsisAddress(value)}
          </button>
        ) : (
          <input
            ref={inputRef}
            value={value}
            onChange={handleChange}
            onFocus={() => setIsFocused(true)}
            onBlur={() => setIsFocused(false)}
            placeholder="Enter address or ENS name"
            disabled={disabled}
            className={clsx(
              'flex-1 h-full bg-transparent text-sm',
              'text-[var(--r-neutral-title-1)] placeholder:text-[var(--r-neutral-foot)]',
              'outline-none min-w-0 font-mono'
            )}
          />
        )}
        {value ? (
          <button
            className="flex-shrink-0 min-w-[28px] min-h-[28px] flex items-center justify-center
              text-[var(--r-neutral-foot)] hover:text-[var(--r-neutral-title-1)]"
            onClick={handleClear}
          >
            <ClearIcon />
          </button>
        ) : (
          <button
            className="flex-shrink-0 min-w-[44px] min-h-[28px] flex items-center justify-center
              text-xs font-medium text-[var(--rabby-brand)]"
            onClick={handlePaste}
          >
            Paste
          </button>
        )}
      </div>
      {error && (
        <p className="text-xs text-[var(--r-red-default)]">{error}</p>
      )}
      {!isValid && value && !error && (
        <p className="text-xs text-[var(--r-red-default)]">
          Invalid address format
        </p>
      )}
    </div>
  );
};

const ClearIcon = () => (
  <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
    <circle cx="8" cy="8" r="7" fill="currentColor" opacity="0.2" />
    <path
      d="M5.5 5.5l5 5M10.5 5.5l-5 5"
      stroke="currentColor"
      strokeWidth="1.2"
      strokeLinecap="round"
    />
  </svg>
);

const ContactBookIcon = () => (
  <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
    <path
      d="M11 1H4.5A1.5 1.5 0 003 2.5v9A1.5 1.5 0 004.5 13H11a1 1 0 001-1V2a1 1 0 00-1-1z"
      stroke="currentColor"
      strokeWidth="1.2"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
    <path
      d="M7.75 5.5a1.25 1.25 0 100-2.5 1.25 1.25 0 000 2.5zM5.5 8.5c0-1.105.895-1.5 2.25-1.5s2.25.395 2.25 1.5"
      stroke="currentColor"
      strokeWidth="1.2"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);
