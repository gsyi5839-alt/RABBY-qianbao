import React from 'react';
import clsx from 'clsx';

type RiskLevel = 'safe' | 'warning' | 'danger' | string;

interface RiskBadgeProps {
  level: RiskLevel;
  className?: string;
}

const config: Record<
  string,
  { bg: string; text: string; label: string }
> = {
  safe: {
    bg: 'bg-[var(--r-green-default)]/10',
    text: 'text-[var(--r-green-default)]',
    label: 'Safe',
  },
  warning: {
    bg: 'bg-amber-500/10',
    text: 'text-amber-600',
    label: 'Warning',
  },
  danger: {
    bg: 'bg-[var(--r-red-default)]/10',
    text: 'text-[var(--r-red-default)]',
    label: 'Danger',
  },
};

/**
 * Colored badge indicating risk level.
 */
export const RiskBadge: React.FC<RiskBadgeProps> = ({ level, className }) => {
  const c = config[level] || config.safe;
  return (
    <span
      className={clsx(
        'inline-flex items-center text-xs font-medium px-2 py-0.5 rounded-md',
        c.bg,
        c.text,
        className,
      )}
    >
      <span
        className={clsx(
          'w-1.5 h-1.5 rounded-full mr-1',
          level === 'safe' && 'bg-[var(--r-green-default)]',
          level === 'warning' && 'bg-amber-500',
          level === 'danger' && 'bg-[var(--r-red-default)]',
        )}
      />
      {c.label}
    </span>
  );
};
