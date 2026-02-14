import React from 'react';
import clsx from 'clsx';
import type { Chain } from '@rabby/shared';

interface ChainIconProps {
  chain?: Chain | null;
  size?: 'sm' | 'md' | 'lg';
  showStatus?: boolean;
  statusColor?: 'green' | 'red' | 'gray';
  className?: string;
}

const sizeMap: Record<string, { icon: string; px: number }> = {
  sm: { icon: 'w-5 h-5', px: 20 },
  md: { icon: 'w-8 h-8', px: 32 },
  lg: { icon: 'w-10 h-10', px: 40 },
};

const statusColorMap: Record<string, string> = {
  green: 'bg-[var(--r-green-default)]',
  red: 'bg-[var(--r-red-default)]',
  gray: 'bg-[var(--r-neutral-foot)]',
};

const Fallback: React.FC<{ size: string }> = ({ size }) => (
  <div
    className={clsx(
      'rounded-full bg-[var(--r-neutral-line)] flex items-center justify-center',
      sizeMap[size].icon
    )}
  >
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
      <circle cx="8" cy="8" r="6" stroke="var(--r-neutral-foot)" strokeWidth="1.2" />
      <text x="8" y="11" fontSize="8" fill="var(--r-neutral-foot)" textAnchor="middle">
        ?
      </text>
    </svg>
  </div>
);

export const ChainIcon: React.FC<ChainIconProps> = ({
  chain,
  size = 'md',
  showStatus = false,
  statusColor = 'green',
  className,
}) => {
  const s = sizeMap[size];

  return (
    <div className={clsx('relative inline-flex flex-shrink-0', className)}>
      {chain?.logo ? (
        <img
          src={chain.logo}
          alt={chain.name}
          className={clsx('rounded-full object-cover', s.icon)}
          width={s.px}
          height={s.px}
        />
      ) : (
        <Fallback size={size} />
      )}
      {showStatus && (
        <div
          className={clsx(
            'absolute -right-0.5 -top-0.5 rounded-full border border-white',
            size === 'sm' ? 'w-2 h-2' : 'w-2.5 h-2.5',
            statusColorMap[statusColor]
          )}
        />
      )}
    </div>
  );
};
