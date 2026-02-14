import React, { useState, useCallback } from 'react';
import clsx from 'clsx';

interface AddressViewerProps {
  address: string;
  ellipsis?: boolean;
  longEllipsis?: boolean;
  showCopy?: boolean;
  showIndex?: boolean;
  index?: number;
  onClick?: () => void;
  className?: string;
}

export const AddressViewer: React.FC<AddressViewerProps> = ({
  address,
  ellipsis = true,
  longEllipsis = false,
  showCopy = true,
  showIndex = false,
  index = -1,
  onClick,
  className,
}) => {
  const [copied, setCopied] = useState(false);

  const lowerAddr = address?.toLowerCase() ?? '';

  const displayAddr = ellipsis
    ? `${lowerAddr.slice(0, longEllipsis ? 8 : 6)}...${lowerAddr.slice(longEllipsis ? -6 : -4)}`
    : lowerAddr;

  const handleCopy = useCallback(
    async (e: React.MouseEvent) => {
      e.stopPropagation();
      try {
        await navigator.clipboard.writeText(address);
        setCopied(true);
        setTimeout(() => setCopied(false), 1500);
      } catch {
        // fallback
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
      className={clsx(
        'inline-flex items-center gap-1',
        onClick && 'cursor-pointer',
        className
      )}
      onClick={onClick}
      title={lowerAddr}
    >
      {showIndex && index >= 0 && (
        <span className="text-xs text-[var(--r-neutral-foot)] mr-1">
          #{index}
        </span>
      )}
      <span className="text-sm font-mono text-[var(--r-neutral-body)]">
        {displayAddr}
      </span>
      {showCopy && (
        <button
          onClick={handleCopy}
          className="flex-shrink-0 flex items-center justify-center w-6 h-6
            text-[var(--r-neutral-foot)] hover:text-[var(--rabby-brand)]
            transition-colors min-w-[44px] min-h-[44px] -m-2"
        >
          {copied ? <CheckIcon /> : <CopyIcon />}
        </button>
      )}
    </div>
  );
};

const CopyIcon = () => (
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
);

const CheckIcon = () => (
  <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
    <path
      d="M3 7l3 3 5-5"
      stroke="var(--r-green-default)"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);
