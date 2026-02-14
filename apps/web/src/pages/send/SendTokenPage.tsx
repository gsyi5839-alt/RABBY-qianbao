import React from 'react';
import { PageHeader } from '../../components/layout';
import { Button } from '../../components/ui';
import { ChainSelector } from '../../components/chain';
import { TokenAmountInput } from '../../components/token';
import { formatTokenAmount } from '../../utils';
import { TokenSelector } from './components/TokenSelector';
import { AddressInput } from './components/AddressInput';
import { GasFeeBar } from './components/GasFeeBar';
import { useSendToken } from './components/useSendToken';

export const SendTokenPage: React.FC = () => {
  const {
    toAddress, setToAddress,
    amount, setAmount,
    selectedToken,
    tokenSelectorVisible, setTokenSelectorVisible,
    gasSpeed, setGasSpeed,
    isSending,
    addressError,
    tokenBalance, usdValue, balanceError, canSubmit,
    gasLevels, nativeTokenPrice,
    chainList, currentChainInfo, tokenList, tokensLoading,
    handleBack, handleMaxClick, handleTokenSelect,
    handleChainChange, handleSelectAddress, handleSend,
    DEFAULT_GAS_LIMIT,
  } = useSendToken();

  return (
    <div className="min-h-screen bg-[var(--r-neutral-bg-1)] flex flex-col">
      <PageHeader title="Send" onBack={handleBack} />

      <div className="flex-1 overflow-y-auto px-4 pb-4">
        {/* Chain selector */}
        <div className="mb-4">
          <ChainSelector
            chains={chainList}
            value={currentChainInfo?.enum}
            onChange={handleChainChange}
          />
        </div>

        {/* To address */}
        <div className="mb-4">
          <AddressInput
            value={toAddress}
            onChange={setToAddress}
            onSelectClick={handleSelectAddress}
            error={addressError}
          />
        </div>

        {/* Token amount */}
        <div className="mb-2">
          <div className="flex items-center justify-between mb-1">
            <span className="text-xs font-medium text-[var(--r-neutral-body)]">
              Amount
            </span>
            {selectedToken && (
              <span className="text-xs text-[var(--r-neutral-foot)]">
                Balance: {formatTokenAmount(tokenBalance)}{' '}
                {selectedToken.display_symbol || selectedToken.symbol}
              </span>
            )}
          </div>
          <TokenAmountInput
            token={selectedToken}
            value={amount}
            onChange={setAmount}
            onTokenClick={() => setTokenSelectorVisible(true)}
            onMax={handleMaxClick}
            usdValue={usdValue}
            error={balanceError}
          />
        </div>

        {/* Gas fee */}
        <div className="mt-4 bg-[var(--r-neutral-card-1)] rounded-xl">
          <GasFeeBar
            gasLevels={gasLevels}
            selectedLevel={gasSpeed}
            onSelectLevel={setGasSpeed}
            gasLimit={DEFAULT_GAS_LIMIT}
            nativeTokenPrice={nativeTokenPrice}
            nativeTokenSymbol={currentChainInfo?.nativeTokenSymbol || 'ETH'}
          />
        </div>
      </div>

      {/* Bottom area */}
      <div className="px-4 pb-6 pt-2 border-t border-[var(--r-neutral-line)]">
        <Button className="w-full" disabled={!canSubmit} onClick={handleSend}>
          {isSending ? 'Sending...' : 'Send'}
        </Button>
      </div>

      {/* Token selector popup */}
      <TokenSelector
        visible={tokenSelectorVisible}
        onClose={() => setTokenSelectorVisible(false)}
        tokens={tokenList}
        selectedToken={selectedToken}
        onSelect={handleTokenSelect}
        isLoading={tokensLoading}
      />
    </div>
  );
};
