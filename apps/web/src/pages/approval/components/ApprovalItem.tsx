import React, { useMemo } from 'react';
import clsx from 'clsx';
import type { TokenApproval } from '@rabby/shared';
import { formatTokenAmount, formatUsdValue, ellipsisAddress } from '../../../utils';
import { RiskBadge } from './RiskBadge';

interface ApprovalItemProps {
  approval: TokenApproval;
  onRevoke: (approval: TokenApproval) => void;
}

/**
 * Renders a single token approval row.
 */
export const ApprovalItem: React.FC<ApprovalItemProps> = ({
  approval,
  onRevoke,
}) => {
  const amountDisplay = useMemo(() => {
    if (approval.is_unlimited) return 'Unlimited';
    return formatTokenAmount(approval.amount);
  }, [approval]);

  const spenderName = approval.spender.name || ellipsisAddress(approval.spender.id);
  const tokenSymbol = approval.token.display_symbol || approval.token.symbol;
  const riskLevel = approval.spender.risk_level || 'safe';

  const tokenValue = useMemo(() => {
    if (!approval.token.price || !approval.token.amount) return null;
    return formatUsdValue(approval.token.price * approval.token.amount);
  }, [approval.token]);

  return (
    <div
      className={clsx(
        'flex flex-col gap-3 p-4',
        'border-b border-[var(--r-neutral-line)]',
      )}
    >
      {/* Token row */}
      <div className="flex items-center gap-3">
        <img
          src={approval.token.logo_url}
          alt={tokenSymbol}
          className="w-8 h-8 rounded-full flex-shrink-0"
          onError={(e) => {
            (e.target as HTMLImageElement).src =
              'data:image/svg+xml,' +
              encodeURIComponent(
                '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">' +
                '<circle cx="16" cy="16" r="16" fill="%23E0E5EC"/>' +
                '<text x="16" y="21" text-anchor="middle" font-size="14" fill="%236A7587">?</text></svg>',
              );
          }}
        />
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <span className="text-sm font-medium text-[var(--r-neutral-title-1)] truncate">
              {tokenSymbol}
            </span>
            {tokenValue && (
              <span className="text-xs text-[var(--r-neutral-foot)]">
                {tokenValue}
              </span>
            )}
          </div>
          <span className="text-xs text-[var(--r-neutral-foot)]">
            Balance: {formatTokenAmount(approval.token.amount)}
          </span>
        </div>
      </div>

      {/* Spender row */}
      <div className="flex items-center justify-between gap-2">
        <div className="flex items-center gap-2 min-w-0 flex-1">
          {approval.spender.logo_url && (
            <img
              src={approval.spender.logo_url}
              alt=""
              className="w-5 h-5 rounded-full flex-shrink-0"
            />
          )}
          <span className="text-sm text-[var(--r-neutral-body)] truncate">
            {spenderName}
          </span>
          <RiskBadge level={riskLevel} />
        </div>
      </div>

      {/* Approved amount + revoke */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-1.5">
          <span className="text-xs text-[var(--r-neutral-foot)]">
            Approved:
          </span>
          <span
            className={clsx(
              'text-sm font-medium',
              approval.is_unlimited
                ? 'text-[var(--r-red-default)]'
                : 'text-[var(--r-neutral-title-1)]',
            )}
          >
            {amountDisplay}
          </span>
          {approval.is_unlimited && (
            <WarningIcon />
          )}
        </div>
        <button
          className={clsx(
            'text-xs font-medium px-3 py-1.5 rounded-lg min-w-[44px] min-h-[44px]',
            'flex items-center justify-center',
            'bg-[var(--r-red-default)]/10 text-[var(--r-red-default)]',
            'hover:bg-[var(--r-red-default)]/20 active:bg-[var(--r-red-default)]/25',
            'transition-colors',
          )}
          onClick={() => onRevoke(approval)}
        >
          Revoke
        </button>
      </div>
    </div>
  );
};

const WarningIcon = () => (
  <svg
    width="14"
    height="14"
    viewBox="0 0 14 14"
    fill="none"
    className="text-[var(--r-red-default)] flex-shrink-0"
  >
    <path
      d="M7 1l6.06 11H.94L7 1z"
      stroke="currentColor"
      strokeWidth="1.2"
      strokeLinejoin="round"
    />
    <path
      d="M7 5v3M7 10v.5"
      stroke="currentColor"
      strokeWidth="1.2"
      strokeLinecap="round"
    />
  </svg>
);
