import React, { useCallback, useMemo } from 'react';
import clsx from 'clsx';
import { useNavigate } from 'react-router-dom';
import { PageHeader } from '../../components/layout';
import { TokenAmountInput } from '../../components/token';
import { Button, toast } from '../../components/ui';
import { formatTokenAmount } from '../../utils';
import { useBridgeState } from './hooks/useBridgeState';
import { ChainPairSelector } from './components/ChainPairSelector';
import { BridgeQuoteList } from './components/BridgeQuoteList';
import { BridgeConfirmPopup } from './components/BridgeConfirmPopup';

export const BridgePage: React.FC = () => {
  const navigate = useNavigate();
  const {
    fromChain,
    toChain,
    chainList,
    handleFromChainChange,
    handleToChainChange,
    switchChains,
    fromToken,
    setFromToken,
    toToken,
    setToToken,
    amount,
    setAmount,
    quotes,
    quotesLoading,
    bestQuote,
    activeQuote,
    selectedQuote,
    setSelectedQuote,
    slippage,
    setSlippage,
    insufficient,
    handleMax,
    confirmVisible,
    setConfirmVisible,
    bridgeLoading,
    setBridgeLoading,
  } = useBridgeState();

  const bestQuoteId = useMemo(() => {
    if (!bestQuote) return null;
    return `${bestQuote.aggregator.id}-${bestQuote.bridge_id}`;
  }, [bestQuote]);

  const selectedQuoteId = useMemo(() => {
    if (!selectedQuote) return null;
    return `${selectedQuote.aggregator.id}-${selectedQuote.bridge_id}`;
  }, [selectedQuote]);

  const toTokenAmount = useMemo(() => {
    if (!activeQuote) return '';
    return formatTokenAmount(activeQuote.to_token_amount);
  }, [activeQuote]);

  const handleBridgeConfirm = useCallback(async () => {
    setBridgeLoading(true);
    try {
      toast('Bridge transaction submitted');
      setConfirmVisible(false);
      setAmount('');
    } catch {
      toast('Bridge failed. Please try again.');
    } finally {
      setBridgeLoading(false);
    }
  }, [setBridgeLoading, setConfirmVisible, setAmount]);

  const btnText = useMemo(() => {
    if (!fromChain || !toChain) return 'Select chains';
    if (!fromToken || !toToken) return 'Select tokens';
    if (!amount || parseFloat(amount) <= 0) return 'Enter amount';
    if (insufficient) return 'Insufficient balance';
    if (quotesLoading) return 'Fetching routes...';
    if (!activeQuote) return 'No route available';
    return 'Bridge';
  }, [
    fromChain,
    toChain,
    fromToken,
    toToken,
    amount,
    insufficient,
    quotesLoading,
    activeQuote,
  ]);

  const btnDisabled = useMemo(
    () =>
      !fromChain ||
      !toChain ||
      !fromToken ||
      !toToken ||
      !amount ||
      parseFloat(amount) <= 0 ||
      insufficient ||
      quotesLoading ||
      !activeQuote,
    [
      fromChain,
      toChain,
      fromToken,
      toToken,
      amount,
      insufficient,
      quotesLoading,
      activeQuote,
    ]
  );

  const estimatedTime = useMemo(() => {
    if (!activeQuote?.duration) return null;
    if (activeQuote.duration < 60) return `~${activeQuote.duration}s`;
    const mins = Math.ceil(activeQuote.duration / 60);
    return `~${mins} min`;
  }, [activeQuote?.duration]);

  return (
    <div className="min-h-screen bg-[var(--r-neutral-bg-2)] flex flex-col">
      <PageHeader
        title="Bridge"
        rightSlot={
          <button
            onClick={() => navigate('/history')}
            className="flex items-center justify-center w-8 h-8 min-w-[44px] min-h-[44px]
              text-[var(--r-neutral-foot)] hover:text-[var(--r-neutral-title-1)]"
          >
            <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
              <path
                d="M10 3v7l4 2M3 10a7 7 0 1014 0 7 7 0 00-14 0z"
                stroke="currentColor"
                strokeWidth="1.5"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          </button>
        }
      />

      <div className="flex-1 overflow-auto px-5 pb-24">
        {/* Chain pair selector */}
        <ChainPairSelector
          fromChain={fromChain}
          toChain={toChain}
          chains={chainList}
          onFromChainChange={handleFromChainChange}
          onToChainChange={handleToChainChange}
          onSwitch={switchChains}
          className="mt-2 mb-4"
        />

        {/* From token + amount */}
        <div className="mb-3">
          <TokenAmountInput
            token={fromToken}
            value={amount}
            onChange={setAmount}
            onMax={handleMax}
            usdValue={
              fromToken && amount
                ? String(
                    (parseFloat(amount) || 0) * (fromToken.price || 0)
                  )
                : undefined
            }
            error={insufficient ? 'Insufficient balance' : undefined}
            placeholder="0.00"
          />
        </div>

        {/* To token (estimated receive) */}
        <div className="p-4 rounded-xl bg-[var(--r-neutral-bg-1)] mb-4">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs text-[var(--r-neutral-foot)]">
              Receive (estimated)
            </span>
            {estimatedTime && (
              <span className="text-xs text-[var(--r-neutral-foot)]">
                {estimatedTime}
              </span>
            )}
          </div>
          <div className="flex items-center gap-3">
            {toToken ? (
              <div className="flex items-center gap-2">
                <img
                  src={toToken.logo_url}
                  alt={toToken.symbol}
                  className="w-6 h-6 rounded-full"
                  onError={(e) => {
                    (e.target as HTMLImageElement).style.display = 'none';
                  }}
                />
                <span className="text-sm font-medium text-[var(--r-neutral-title-1)]">
                  {toToken.display_symbol || toToken.symbol}
                </span>
              </div>
            ) : (
              <span className="text-sm text-[var(--r-neutral-foot)]">
                Select destination token
              </span>
            )}
            <div className="flex-1 text-right">
              {quotesLoading && amount && parseFloat(amount) > 0 ? (
                <div className="h-6 w-20 ml-auto bg-[var(--r-neutral-line)] rounded animate-pulse" />
              ) : (
                <span className="text-lg font-semibold text-[var(--r-neutral-title-1)]">
                  {toTokenAmount || '0'}
                </span>
              )}
            </div>
          </div>
        </div>

        {/* Quote list */}
        <BridgeQuoteList
          quotes={quotes}
          loading={quotesLoading}
          toToken={toToken}
          bestQuoteId={bestQuoteId}
          selectedQuoteId={selectedQuoteId}
          onSelectQuote={setSelectedQuote}
          className="mt-2"
        />

        {/* Bridge info */}
        {activeQuote && (
          <div className="mt-4 flex flex-col gap-2 p-4 rounded-xl bg-[var(--r-neutral-bg-1)]">
            <div className="flex items-center justify-between">
              <span className="text-xs text-[var(--r-neutral-foot)]">
                Bridge Fee
              </span>
              <span className="text-xs font-medium text-[var(--r-neutral-title-1)]">
                {activeQuote.protocol_fee
                  ? `$${activeQuote.protocol_fee.usd_value.toFixed(2)}`
                  : 'Free'}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-xs text-[var(--r-neutral-foot)]">
                Slippage
              </span>
              <span className="text-xs font-medium text-[var(--r-neutral-title-1)]">
                {slippage}%
              </span>
            </div>
          </div>
        )}
      </div>

      {/* Bottom action bar */}
      <div
        className={clsx(
          'fixed bottom-0 left-0 right-0 p-5 pt-3',
          'bg-[var(--r-neutral-bg-2)]',
          'border-t border-[var(--r-neutral-line)]'
        )}
      >
        <Button
          variant="primary"
          size="lg"
          fullWidth
          disabled={btnDisabled}
          loading={quotesLoading}
          onClick={() => {
            if (!btnDisabled) setConfirmVisible(true);
          }}
        >
          {btnText}
        </Button>
      </div>

      {/* Confirm popup */}
      <BridgeConfirmPopup
        visible={confirmVisible}
        onClose={() => setConfirmVisible(false)}
        onConfirm={handleBridgeConfirm}
        fromChain={fromChain}
        toChain={toChain}
        fromToken={fromToken}
        toToken={toToken}
        amount={amount}
        activeQuote={activeQuote}
        slippage={slippage}
        loading={bridgeLoading}
      />
    </div>
  );
};
