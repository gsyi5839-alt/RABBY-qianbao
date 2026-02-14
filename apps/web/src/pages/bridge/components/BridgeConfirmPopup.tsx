import React, { useMemo } from 'react';
import type { TokenItem, Chain } from '@rabby/shared';
import type { BridgeQuoteItem } from '../hooks/useBridgeState';
import { Popup, Button } from '../../../components/ui';
import { ChainIcon } from '../../../components/chain';
import { formatTokenAmount, formatUsdValue } from '../../../utils';

const FALLBACK_ICON =
  'data:image/svg+xml,' +
  encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">' +
      '<circle cx="16" cy="16" r="16" fill="%23E0E5EC"/></svg>'
  );

interface BridgeConfirmPopupProps {
  visible: boolean;
  onClose: () => void;
  onConfirm: () => void;
  fromChain: Chain | null;
  toChain: Chain | null;
  fromToken: TokenItem | null;
  toToken: TokenItem | null;
  amount: string;
  activeQuote: BridgeQuoteItem | null;
  slippage: number;
  loading?: boolean;
}

export const BridgeConfirmPopup: React.FC<BridgeConfirmPopupProps> = ({
  visible,
  onClose,
  onConfirm,
  fromChain,
  toChain,
  fromToken,
  toToken,
  amount,
  activeQuote,
  slippage,
  loading = false,
}) => {
  const gasFee = useMemo(() => {
    if (!activeQuote?.gas_fee) return '--';
    return formatUsdValue(activeQuote.gas_fee.usd_value);
  }, [activeQuote]);

  const duration = useMemo(() => {
    if (!activeQuote?.duration) return '--';
    if (activeQuote.duration < 60) return `~${activeQuote.duration}s`;
    const mins = Math.ceil(activeQuote.duration / 60);
    return `~${mins} min`;
  }, [activeQuote?.duration]);

  const receiveAmount = useMemo(() => {
    if (!activeQuote) return '--';
    return formatTokenAmount(activeQuote.to_token_amount);
  }, [activeQuote]);

  return (
    <Popup visible={visible} onClose={onClose} title="Confirm Bridge" height="auto">
      <div className="flex flex-col gap-4 pb-4">
        {/* Chain route */}
        <div className="flex items-center justify-center gap-3 py-2">
          <ChainBadge chain={fromChain} label="From" />
          <svg
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            className="text-[var(--r-neutral-foot)] flex-shrink-0"
          >
            <path
              d="M5 12h14M14 7l5 5-5 5"
              stroke="currentColor"
              strokeWidth="1.5"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
          <ChainBadge chain={toChain} label="To" />
        </div>

        {/* Token amounts */}
        <div className="flex flex-col gap-3 p-4 rounded-xl bg-[var(--r-neutral-bg-2)]">
          <TokenRow label="Send" token={fromToken} amount={amount} />
          <div className="h-px bg-[var(--r-neutral-line)]" />
          <TokenRow
            label="Receive (est.)"
            token={toToken}
            amount={receiveAmount}
          />
        </div>

        {/* Details */}
        <div className="flex flex-col gap-2">
          <DetailRow label="Bridge" value={activeQuote?.bridge?.name || activeQuote?.aggregator?.name || '--'} />
          <DetailRow label="Gas Fee" value={gasFee} />
          <DetailRow label="Est. Time" value={duration} />
          <DetailRow label="Slippage" value={`${slippage}%`} />
        </div>

        {/* Confirm */}
        <Button
          variant="primary"
          size="lg"
          fullWidth
          loading={loading}
          onClick={onConfirm}
        >
          Confirm Bridge
        </Button>
      </div>
    </Popup>
  );
};

const ChainBadge: React.FC<{ chain: Chain | null; label: string }> = ({
  chain,
  label,
}) => (
  <div className="flex flex-col items-center gap-1">
    <ChainIcon chain={chain} size="md" />
    <span className="text-xs text-[var(--r-neutral-foot)]">
      {chain?.name || label}
    </span>
  </div>
);

const TokenRow: React.FC<{
  label: string;
  token: TokenItem | null;
  amount: string;
}> = ({ label, token, amount }) => (
  <div className="flex items-center justify-between">
    <div className="flex items-center gap-2">
      <img
        src={token?.logo_url || FALLBACK_ICON}
        alt={token?.symbol || ''}
        className="w-7 h-7 rounded-full"
        onError={(e) => {
          (e.target as HTMLImageElement).src = FALLBACK_ICON;
        }}
      />
      <div>
        <p className="text-xs text-[var(--r-neutral-foot)]">{label}</p>
        <p className="text-sm font-semibold text-[var(--r-neutral-title-1)]">
          {token?.display_symbol || token?.symbol || '--'}
        </p>
      </div>
    </div>
    <span className="text-base font-semibold text-[var(--r-neutral-title-1)]">
      {amount ? formatTokenAmount(amount) : '0'}
    </span>
  </div>
);

const DetailRow: React.FC<{ label: string; value: string }> = ({
  label,
  value,
}) => (
  <div className="flex items-center justify-between">
    <span className="text-xs text-[var(--r-neutral-foot)]">{label}</span>
    <span className="text-xs font-medium text-[var(--r-neutral-title-1)]">
      {value}
    </span>
  </div>
);
