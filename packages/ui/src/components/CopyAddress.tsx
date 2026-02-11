import React, { useState, useCallback } from 'react';

interface CopyAddressProps {
  address: string;
  className?: string;
  children?: React.ReactNode;
}

export function CopyAddress({ address, className = '', children }: CopyAddressProps) {
  const [copied, setCopied] = useState(false);

  const handleCopy = useCallback(async () => {
    try {
      await navigator.clipboard.writeText(address);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {}
  }, [address]);

  return (
    <button
      className={className}
      onClick={handleCopy}
      title={copied ? 'Copied!' : 'Copy address'}
      style={{
        background: 'none',
        border: 'none',
        cursor: 'pointer',
        padding: '4px 8px',
        borderRadius: 'var(--rabby-radius-xs)',
        color: copied ? 'var(--r-green-default)' : 'var(--r-neutral-foot)',
        transition: 'var(--rabby-transition-fast)',
        display: 'inline-flex',
        alignItems: 'center',
        gap: 4,
        fontSize: 13,
      }}
    >
      {children || (copied ? '✓ Copied' : '📋 Copy')}
    </button>
  );
}
