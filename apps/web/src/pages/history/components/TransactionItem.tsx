import React, { useMemo } from 'react';
import clsx from 'clsx';
import type { TxHistoryItem } from '../../../services/api/history';
import type { TokenItem } from '../../../services/api/balance';
import { formatTokenAmount, formatUsdValue, sinceTime } from '../../../utils';
import { ellipsisAddress } from '../../../utils/address';

// ── Tx type icons (inline SVGs) ─────────────────────────────────────────────

const SendIcon = () => (
  <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
    <path d="M4 10h12M12 6l4 4-4 4" stroke="var(--r-red-default)" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);
const ReceiveIcon = () => (
  <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
    <path d="M16 10H4M8 6l-4 4 4 4" stroke="var(--r-green-default)" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);
const ApproveIcon = () => (
  <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
    <path d="M6 10l3 3 5-5" stroke="var(--rabby-brand)" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);
const SwapIcon = () => (
  <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
    <path d="M4 7h12M16 13H4M14 5l2 2-2 2M6 11l-2 2 2 2" stroke="var(--rabby-brand)" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);
const ContractIcon = () => (
  <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
    <rect x="4" y="4" width="12" height="12" rx="2" stroke="var(--r-neutral-foot)" strokeWidth="1.5" />
    <path d="M8 8h4M8 12h2" stroke="var(--r-neutral-foot)" strokeWidth="1.5" strokeLinecap="round" />
  </svg>
);

// ── Helpers ──────────────────────────────────────────────────────────────────

type TxType = 'send' | 'receive' | 'approve' | 'swap' | 'contract';

function resolveTxType(item: TxHistoryItem): TxType {
  const cate = item.cate_id || '';
  if (cate === 'approve' || item.token_approve) return 'approve';
  if (cate === 'receive' || (!item.sends.length && item.receives.length))
    return 'receive';
  if (cate === 'send' || (item.sends.length && !item.receives.length))
    return 'send';
  if (item.sends.length && item.receives.length) return 'swap';
  return 'contract';
}

const typeLabel: Record<TxType, string> = {
  send: 'Send',
  receive: 'Receive',
  approve: 'Approve',
  swap: 'Swap',
  contract: 'Contract Call',
};

const typeIcons: Record<TxType, React.ReactNode> = {
  send: <SendIcon />,
  receive: <ReceiveIcon />,
  approve: <ApproveIcon />,
  swap: <SwapIcon />,
  contract: <ContractIcon />,
};

// ── Props ────────────────────────────────────────────────────────────────────

interface TransactionItemProps {
  item: TxHistoryItem;
  tokenDict: Record<string, TokenItem>;
  cateDict?: Record<string, { id: string; name: string }>;
  onClick?: (item: TxHistoryItem) => void;
}

/**
 * Renders a single transaction row in the history list.
 */
export const TransactionItem: React.FC<TransactionItemProps> = ({
  item,
  tokenDict,
  cateDict,
  onClick,
}) => {
  const txType = useMemo(() => resolveTxType(item), [item]);
  const isFailed = item.tx?.status === 0;

  const description = useMemo(() => {
    if (cateDict && item.cate_id && cateDict[item.cate_id]) {
      return cateDict[item.cate_id].name;
    }
    if (txType === 'approve' && item.token_approve) {
      const tok = tokenDict[item.token_approve.token_id];
      return `Approve ${tok?.symbol || 'Token'}`;
    }
    if (txType === 'send' && item.sends[0]) {
      const tok = tokenDict[item.sends[0].token_id];
      const amt = formatTokenAmount(item.sends[0].amount);
      return `Send ${amt} ${tok?.symbol || ''}`;
    }
    if (txType === 'receive' && item.receives[0]) {
      const tok = tokenDict[item.receives[0].token_id];
      const amt = formatTokenAmount(item.receives[0].amount);
      return `Receive ${amt} ${tok?.symbol || ''}`;
    }
    if (txType === 'swap') {
      const sTok = tokenDict[item.sends[0]?.token_id];
      const rTok = tokenDict[item.receives[0]?.token_id];
      return `Swap ${sTok?.symbol || '?'} for ${rTok?.symbol || '?'}`;
    }
    return item.tx?.name || typeLabel[txType];
  }, [item, txType, tokenDict, cateDict]);

  const gasDisplay = useMemo(() => {
    if (!item.tx?.eth_gas_fee) return null;
    return `Gas: ${formatUsdValue(item.tx.usd_gas_fee)}`;
  }, [item.tx]);

  return (
    <button
      className={clsx(
        'flex items-center gap-3 px-4 py-3 w-full text-left',
        'hover:bg-[var(--r-neutral-bg-2)] transition-colors active:bg-[var(--r-neutral-bg-2)]',
        'border-b border-[var(--r-neutral-line)]',
        isFailed && 'opacity-60',
      )}
      onClick={() => onClick?.(item)}
    >
      {/* Icon */}
      <div className="w-9 h-9 rounded-full bg-[var(--r-neutral-bg-2)] flex items-center justify-center flex-shrink-0">
        {typeIcons[txType]}
      </div>

      {/* Main content */}
      <div className="flex-1 min-w-0">
        <div className="flex items-center justify-between gap-2">
          <span className="text-sm font-medium text-[var(--r-neutral-title-1)] truncate">
            {description}
          </span>
          {/* Status badge */}
          {isFailed && (
            <span className="flex-shrink-0 text-xs px-1.5 py-0.5 rounded bg-[var(--r-red-default)]/10 text-[var(--r-red-default)]">
              Failed
            </span>
          )}
        </div>
        <div className="flex items-center justify-between gap-2 mt-0.5">
          <span className="text-xs text-[var(--r-neutral-foot)] truncate">
            {item.tx?.name ? ellipsisAddress(item.id) : ellipsisAddress(item.id)}
          </span>
          <span className="flex-shrink-0 text-xs text-[var(--r-neutral-foot)]">
            {sinceTime(item.time_at)}
          </span>
        </div>
        {gasDisplay && (
          <div className="text-xs text-[var(--r-neutral-foot)] mt-0.5">
            {gasDisplay}
          </div>
        )}
      </div>
    </button>
  );
};
