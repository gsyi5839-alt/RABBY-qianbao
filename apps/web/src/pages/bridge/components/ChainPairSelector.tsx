import React from 'react';
import clsx from 'clsx';
import type { Chain } from '@rabby/shared';
import { ChainSelector, ChainIcon } from '../../../components/chain';

interface ChainPairSelectorProps {
  fromChain: Chain | null;
  toChain: Chain | null;
  chains: Chain[];
  onFromChainChange: (chain: Chain) => void;
  onToChainChange: (chain: Chain) => void;
  onSwitch: () => void;
  className?: string;
}

export const ChainPairSelector: React.FC<ChainPairSelectorProps> = ({
  fromChain,
  toChain,
  chains,
  onFromChainChange,
  onToChainChange,
  onSwitch,
  className,
}) => {
  const fromExcluded = chains.filter(
    (c) => c.enum !== toChain?.enum
  );
  const toExcluded = chains.filter(
    (c) => c.enum !== fromChain?.enum
  );

  return (
    <div className={clsx('flex items-center gap-3', className)}>
      {/* From chain */}
      <div className="flex-1 min-w-0">
        <p className="text-xs text-[var(--r-neutral-foot)] mb-1 px-1">From</p>
        <ChainSelector
          chains={fromExcluded}
          value={fromChain?.enum}
          onChange={onFromChainChange}
          title="From Chain"
          className="w-full"
        />
      </div>

      {/* Switch button */}
      <button
        onClick={onSwitch}
        className={clsx(
          'flex items-center justify-center w-8 h-8 rounded-full mt-5',
          'bg-[var(--r-neutral-bg-1)] border border-[var(--r-neutral-line)]',
          'hover:border-[var(--rabby-brand)] hover:text-[var(--rabby-brand)]',
          'transition-colors text-[var(--r-neutral-foot)] flex-shrink-0',
          'min-w-[44px] min-h-[44px]'
        )}
      >
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
          <path
            d="M3 8h10M10 5l3 3-3 3"
            stroke="currentColor"
            strokeWidth="1.5"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </button>

      {/* To chain */}
      <div className="flex-1 min-w-0">
        <p className="text-xs text-[var(--r-neutral-foot)] mb-1 px-1">To</p>
        <ChainSelector
          chains={toExcluded}
          value={toChain?.enum}
          onChange={onToChainChange}
          title="To Chain"
          className="w-full"
        />
      </div>
    </div>
  );
};
