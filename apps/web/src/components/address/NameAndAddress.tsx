import React, { useState, useCallback } from 'react';
import clsx from 'clsx';

interface NameAndAddressProps {
  address: string;
  name?: string;
  className?: string;
  nameClassName?: string;
  addressClassName?: string;
  showCopy?: boolean;
  copyIconClassName?: string;
}

export const NameAndAddress: React.FC<NameAndAddressProps> = ({
  address,
  name,
  className,
  nameClassName,
  addressClassName,
  showCopy = true,
  copyIconClassName,
}) => {
  const [copied, setCopied] = useState(false);
  const lowerAddr = address?.toLowerCase() ?? '';

  const shortAddr = name
    ? `(${lowerAddr.slice(0, 6)}...${lowerAddr.slice(-4)})`
    : `${lowerAddr.slice(0, 8)}...${lowerAddr.slice(-6)}`;

  const handleCopy = useCallback(
    async (e: React.MouseEvent) => {
      e.stopPropagation();
      try {
        await navigator.clipboard.writeText(address);
        setCopied(true);
        setTimeout(() => setCopied(false), 1500);
      } catch {
        const el = document.createElement('textarea');
        el.value = address;
        document.body.appendChild(el);
        el.select();
        document.execCommand('copy');
        document.body.removeChild(el);
        setCopied(true);
        setTimeout(() => setCopied(false), 1500);
      }
    },
    [address]
  );

  return (
    <div
      className={clsx('inline-flex items-center gap-1 min-w-0', className)}
      title={lowerAddr}
    >
      {name && (
        <span
          className={clsx(
            'text-sm font-medium text-[var(--r-neutral-title-1)] truncate max-w-[120px]',
            nameClassName
          )}
          title={name}
        >
          {name}
        </span>
      )}
      <span
        className={clsx(
          'text-sm font-mono text-[var(--r-neutral-foot)] whitespace-nowrap',
          addressClassName
        )}
      >
        {shortAddr}
      </span>
      {showCopy && (
        <button
          onClick={handleCopy}
          className={clsx(
            'flex-shrink-0 flex items-center justify-center',
            'text-[var(--r-neutral-foot)] hover:text-[var(--rabby-brand)]',
            'transition-colors min-w-[44px] min-h-[44px] -m-2',
            copyIconClassName
          )}
        >
          {copied ? (
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
              <path
                d="M3 7l3 3 5-5"
                stroke="var(--r-green-default)"
                strokeWidth="1.5"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          ) : (
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
              <rect
                x="4.5"
                y="4.5"
                width="8"
                height="8"
                rx="1.5"
                stroke="currentColor"
                strokeWidth="1.2"
              />
              <path
                d="M9.5 4.5V3a1.5 1.5 0 00-1.5-1.5H3A1.5 1.5 0 001.5 3v5A1.5 1.5 0 003 9.5h1.5"
                stroke="currentColor"
                strokeWidth="1.2"
              />
            </svg>
          )}
        </button>
      )}
    </div>
  );
};
