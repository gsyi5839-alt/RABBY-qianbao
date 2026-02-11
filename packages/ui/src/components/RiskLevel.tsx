import React from 'react';

type RiskLevelType = 'safe' | 'info' | 'warning' | 'danger' | 'forbidden';

const RISK_CONFIG: Record<RiskLevelType, { color: string; bg: string; icon: string; label: string }> = {
  safe: { color: 'var(--r-green-default)', bg: 'var(--r-green-light)', icon: '✅', label: 'Safe' },
  info: { color: 'var(--r-blue-default)', bg: 'var(--r-blue-light-1)', icon: 'ℹ️', label: 'Info' },
  warning: { color: 'var(--r-orange-default)', bg: 'var(--r-orange-light)', icon: '⚠️', label: 'Warning' },
  danger: { color: 'var(--r-red-default)', bg: 'var(--r-red-light)', icon: '🚫', label: 'Danger' },
  forbidden: { color: 'var(--r-red-dark)', bg: 'var(--r-red-light)', icon: '🛑', label: 'Forbidden' },
};

interface RiskLevelProps {
  level: RiskLevelType;
  message?: string;
  className?: string;
}

export function RiskLevel({ level, message, className = '' }: RiskLevelProps) {
  const config = RISK_CONFIG[level];
  return (
    <div
      className={className}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 8,
        padding: '8px 12px',
        borderRadius: 'var(--rabby-radius-sm)',
        background: config.bg,
        border: `1px solid ${config.color}`,
        fontSize: 13,
        color: config.color,
      }}
    >
      <span>{config.icon}</span>
      <span>{message || config.label}</span>
    </div>
  );
}
