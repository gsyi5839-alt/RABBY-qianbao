import React, { useMemo } from 'react';
import clsx from 'clsx';
import type { TokenItem } from '@rabby/shared';
import type { DexQuoteItem } from '../hooks/useSwapState';
import { Popup } from '../../../components/ui';
import { Button } from '../../../components/ui';
import { formatTokenAmount, formatUsdValue } from '../../../utils';

const FALLBACK_ICON =
  'data:image/svg+xml,' +
  encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">' +
      '<circle cx="16" cy="16" r="16" fill="%23E0E5EC"/></svg>'
  );

interface SwapConfirmPopupProps {
  visible: boolean;
  onClose: () => void;
  onConfirm: () => void;
  fromToken: TokenItem | null;
  toToken: TokenItem | null;
  fromAmount: string;
  toAmount: string;
  activeQuote: DexQuoteItem | null;
  slippage: number;
  loading?: boolean;
}

export const SwapConfirmPopup: React.FC<SwapConfirmPopupProps> = ({
  visible,
  onClose,
  onConfirm,
  fromToken,
  toToken,
  fromAmount,
  toAmount,
  activeQuote,
  slippage,
  loading = false,
}) => {
  const rate = useMemo(() => {
    if (!fromToken || !toToken || !fromAmount || !toAmount) return '--';
    const from = parseFloat(fromAmount);
    const to = parseFloat(toAmount);
    if (from === 0) return '--';
    const r = to / from;
    return `1 ${fromToken.symbol} = ${formatTokenAmount(r)} ${toToken.symbol}`;
  }, [fromToken, toToken, fromAmount, toAmount]);

  const minReceived = useMemo(() => {
    if (!toAmount || !toToken) return '--';
    const to = parseFloat(toAmount);
    const min = to * (1 - slippage / 100);
    return `${formatTokenAmount(min)} ${toToken.symbol}`;
  }, [toAmount, toToken, slippage]);

  const gasFeeUsd = useMemo(() => {
    if (!activeQuote?.quote?.gas) return '--';
    return formatUsdValue(activeQuote.quote.gas.gas_cost_usd_value);
  }, [activeQuote]);

  return (
    <Popup visible={visible} onClose={onClose} title="Confirm Swap" height="auto">
      <div className="flex flex-col gap-4 pb-4">
        {/* From / To summary */}
        <div className="flex flex-col gap-3 p-4 rounded-xl bg-[var(--r-neutral-bg-2)]">
          <TokenRow
            label="From"
            token={fromToken}
            amount={fromAmount}
          />
          <div className="flex justify-center">
            <svg
              width="16"
              height="16"
              viewBox="0 0 16 16"
              fill="none"
              className="text-[var(--r-neutral-foot)]"
            >
              <path
                d="M8 3v10M8 13l-3-3M8 13l3-3"
                stroke="currentColor"
                strokeWidth="1.5"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          </div>
          <TokenRow
            label="To"
            token={toToken}
            amount={toAmount}
          />
        </div>

        {/* Details */}
        <div className="flex flex-col gap-2">
          <DetailRow label="Rate" value={rate} />
          <DetailRow label="Min. Received" value={minReceived} />
          <DetailRow label="Slippage" value={`${slippage}%`} />
          <DetailRow label="Gas Fee" value={gasFeeUsd} />
          {activeQuote && (
            <DetailRow label="DEX" value={activeQuote.dex.name} />
          )}
        </div>

        {/* Confirm button */}
        <Button
          variant="primary"
          size="lg"
          fullWidth
          loading={loading}
          onClick={onConfirm}
        >
          Confirm Swap
        </Button>
      </div>
    </Popup>
  );
};

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
        className="w-8 h-8 rounded-full"
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
