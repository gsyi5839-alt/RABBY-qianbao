import React from 'react';

interface TokenIconProps {
  src?: string;
  symbol?: string;
  chain?: string;
  size?: number;
  className?: string;
}

export function TokenIcon({ src, symbol, chain, size = 32, className = '' }: TokenIconProps) {
  const fallbackLetter = symbol ? symbol[0].toUpperCase() : '?';
  return (
    <span className={className} style={{ position: 'relative', display: 'inline-flex', width: size, height: size }}>
      {src ? (
        <img
          src={src}
          alt={symbol || ''}
          style={{ width: size, height: size, borderRadius: '50%', objectFit: 'cover' }}
          onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
        />
      ) : (
        <span
          style={{
            width: size,
            height: size,
            borderRadius: '50%',
            background: 'var(--r-blue-light-1)',
            color: 'var(--r-blue-default)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: size * 0.45,
            fontWeight: 600,
          }}
        >
          {fallbackLetter}
        </span>
      )}
      {chain && (
        <span
          style={{
            position: 'absolute',
            bottom: -2,
            right: -2,
            width: size * 0.4,
            height: size * 0.4,
            borderRadius: '50%',
            background: 'var(--r-neutral-bg-1)',
            border: '1px solid var(--r-neutral-line)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: 8,
          }}
        >
          {chain.slice(0, 1).toUpperCase()}
        </span>
      )}
    </span>
  );
}
