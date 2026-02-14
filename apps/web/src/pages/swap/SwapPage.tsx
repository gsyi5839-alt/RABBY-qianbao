import React, { useCallback, useMemo } from 'react';
import clsx from 'clsx';
import { useNavigate } from 'react-router-dom';
import { PageHeader } from '../../components/layout';
import { ChainSelector } from '../../components/chain';
import { toast } from '../../components/ui';
import { formatUsdValue } from '../../utils';
import { useSwapState } from './hooks/useSwapState';
import { SwapTokenInput } from './components/SwapTokenInput';
import { QuoteList } from './components/QuoteList';
import { SlippageSettings } from './components/SlippageSettings';
import { SwapConfirmPopup } from './components/SwapConfirmPopup';
import { Button } from '../../components/ui';

export const SwapPage: React.FC = () => {
  const navigate = useNavigate();
  const {
    chain,
    chainList,
    switchChain,
    fromToken,
    setFromToken,
    toToken,
    setToToken,
    fromAmount,
    setFromAmount,
    toAmount,
    quotes,
    quotesLoading,
    bestQuote,
    activeQuote,
    selectedDex,
    setSelectedDex,
    slippage,
    setSlippage,
    autoSlippage,
    setAutoSlippage,
    isCustomSlippage,
    setIsCustomSlippage,
    SLIPPAGE_PRESETS,
    priceImpact,
    insufficient,
    exchangeTokens,
    handleMax,
    confirmVisible,
    setConfirmVisible,
    swapLoading,
    setSwapLoading,
  } = useSwapState();

  const bestDexId = useMemo(() => bestQuote?.dex.id || null, [bestQuote]);

  const handleSwapConfirm = useCallback(async () => {
    setSwapLoading(true);
    try {
      // In a real implementation, this would call the swap API
      toast('Swap submitted successfully');
      setConfirmVisible(false);
      setFromAmount('');
    } catch {
      toast('Swap failed. Please try again.');
    } finally {
      setSwapLoading(false);
    }
  }, [setSwapLoading, setConfirmVisible, setFromAmount]);

  const btnText = useMemo(() => {
    if (!fromToken || !toToken) return 'Select tokens';
    if (!fromAmount || parseFloat(fromAmount) <= 0) return 'Enter amount';
    if (insufficient) return 'Insufficient balance';
    if (quotesLoading) return 'Fetching quotes...';
    if (!activeQuote) return 'No quote available';
    return 'Swap';
  }, [fromToken, toToken, fromAmount, insufficient, quotesLoading, activeQuote]);

  const btnDisabled = useMemo(
    () =>
      !fromToken ||
      !toToken ||
      !fromAmount ||
      parseFloat(fromAmount) <= 0 ||
      insufficient ||
      quotesLoading ||
      !activeQuote,
    [fromToken, toToken, fromAmount, insufficient, quotesLoading, activeQuote]
  );

  const gasFeeDisplay = useMemo(() => {
    if (!activeQuote?.quote?.gas) return null;
    return formatUsdValue(activeQuote.quote.gas.gas_cost_usd_value);
  }, [activeQuote]);

  return (
    <div className="min-h-screen bg-[var(--r-neutral-bg-2)] flex flex-col">
      <PageHeader
        title="Swap"
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
        {/* Chain selector */}
        <div className="mb-3 mt-2">
          <ChainSelector
            chains={chainList.filter((c) => !c.isTestnet)}
            value={chain?.enum}
            onChange={switchChain}
            title="Select Chain"
          />
        </div>

        {/* Token pair card */}
        <div className="relative rounded-2xl bg-[var(--r-neutral-card-1,var(--r-neutral-bg-1))] overflow-hidden">
          <SwapTokenInput
            type="from"
            token={fromToken}
            value={fromAmount}
            onValueChange={setFromAmount}
            onMax={handleMax}
            insufficient={insufficient}
          />

          {/* Divider + switch button */}
          <div className="relative h-px bg-[var(--r-neutral-line)]">
            <button
              onClick={exchangeTokens}
              className={clsx(
                'absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2',
                'w-8 h-8 rounded-full flex items-center justify-center',
                'bg-[var(--r-neutral-bg-1)] border border-[var(--r-neutral-line)]',
                'hover:border-[var(--rabby-brand)] hover:text-[var(--rabby-brand)]',
                'transition-colors text-[var(--r-neutral-foot)]',
                'min-w-[44px] min-h-[44px]'
              )}
            >
              <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                <path
                  d="M5 3v10M5 13L3 11M5 13l2-2M11 13V3M11 3L9 5M11 3l2 2"
                  stroke="currentColor"
                  strokeWidth="1.5"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </button>
          </div>

          <SwapTokenInput
            type="to"
            token={toToken}
            value={toAmount}
            loading={quotesLoading && !!fromAmount && parseFloat(fromAmount) > 0}
          />
        </div>

        {/* Insufficient balance warning */}
        {insufficient && (
          <div className="mt-2 px-1">
            <p className="text-xs text-[var(--r-red-default)]">
              Insufficient balance
            </p>
          </div>
        )}

        {/* Quote list */}
        <QuoteList
          quotes={quotes}
          loading={quotesLoading}
          toToken={toToken}
          bestDexId={bestDexId}
          selectedDex={selectedDex}
          onSelectDex={setSelectedDex}
          className="mt-4"
        />

        {/* Swap details (price impact, gas, slippage) */}
        {activeQuote && (
          <div className="mt-4 flex flex-col gap-3 p-4 rounded-xl bg-[var(--r-neutral-bg-1)]">
            {/* Price impact */}
            {priceImpact !== null && (
              <div className="flex items-center justify-between">
                <span className="text-xs text-[var(--r-neutral-foot)]">
                  Price Impact
                </span>
                <span
                  className={clsx(
                    'text-xs font-medium',
                    priceImpact > 5
                      ? 'text-[var(--r-red-default)]'
                      : priceImpact > 1
                      ? 'text-[var(--r-orange-default)]'
                      : 'text-[var(--r-green-default)]'
                  )}
                >
                  {priceImpact.toFixed(2)}%
                </span>
              </div>
            )}

            {/* Gas fee */}
            {gasFeeDisplay && (
              <div className="flex items-center justify-between">
                <span className="text-xs text-[var(--r-neutral-foot)]">
                  Estimated Gas
                </span>
                <span className="text-xs font-medium text-[var(--r-neutral-title-1)]">
                  {gasFeeDisplay}
                </span>
              </div>
            )}

            {/* Slippage settings */}
            <SlippageSettings
              slippage={slippage}
              onSlippageChange={setSlippage}
              presets={SLIPPAGE_PRESETS}
              autoSlippage={autoSlippage}
              onAutoSlippageChange={setAutoSlippage}
              isCustom={isCustomSlippage}
              onCustomChange={setIsCustomSlippage}
            />
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
      <SwapConfirmPopup
        visible={confirmVisible}
        onClose={() => setConfirmVisible(false)}
        onConfirm={handleSwapConfirm}
        fromToken={fromToken}
        toToken={toToken}
        fromAmount={fromAmount}
        toAmount={toAmount}
        activeQuote={activeQuote}
        slippage={slippage}
        loading={swapLoading}
      />
    </div>
  );
};
