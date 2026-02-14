import React, { useState, useMemo, useCallback } from 'react';
import clsx from 'clsx';
import type { Chain } from '@rabby/shared';
import { Popup } from '../ui/Popup';
import { Input } from '../ui/Input';
import { Empty } from '../ui/Empty';
import { ChainIcon } from './ChainIcon';

interface ChainSelectorProps {
  chains: Chain[];
  value?: string;
  onChange: (chain: Chain) => void;
  className?: string;
  title?: React.ReactNode;
}

export const ChainSelector: React.FC<ChainSelectorProps> = ({
  chains,
  value,
  onChange,
  className,
  title = 'Select Chain',
}) => {
  const [visible, setVisible] = useState(false);
  const [search, setSearch] = useState('');

  const selectedChain = useMemo(
    () => chains.find((c) => c.enum === value || c.serverId === value),
    [chains, value]
  );

  const filteredChains = useMemo(() => {
    if (!search.trim()) return chains;
    const q = search.toLowerCase();
    return chains.filter(
      (c) =>
        c.name.toLowerCase().includes(q) ||
        c.enum.toLowerCase().includes(q) ||
        c.nativeTokenSymbol.toLowerCase().includes(q)
    );
  }, [chains, search]);

  const handleSelect = useCallback(
    (chain: Chain) => {
      onChange(chain);
      setVisible(false);
      setSearch('');
    },
    [onChange]
  );

  return (
    <>
      {/* Trigger */}
      <button
        className={clsx(
          'inline-flex items-center gap-2 px-3 h-10 rounded-xl',
          'border border-[var(--r-neutral-line)] bg-[var(--r-neutral-bg-1)]',
          'hover:border-[var(--rabby-brand)] transition-colors',
          'min-w-[44px] min-h-[44px]',
          className
        )}
        onClick={() => setVisible(true)}
      >
        {selectedChain ? (
          <>
            <ChainIcon chain={selectedChain} size="sm" />
            <span className="text-sm font-medium text-[var(--r-neutral-title-1)] whitespace-nowrap truncate">
              {selectedChain.name}
            </span>
          </>
        ) : (
          <span className="text-sm text-[var(--r-neutral-foot)]">
            Select chain
          </span>
        )}
        <ArrowDownIcon />
      </button>

      {/* Popup list */}
      <Popup
        visible={visible}
        onClose={() => {
          setVisible(false);
          setSearch('');
        }}
        title={title}
        height="70vh"
      >
        <div className="mb-3">
          <Input
            placeholder="Search chain..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            prefix={<SearchIcon />}
          />
        </div>

        {filteredChains.length === 0 ? (
          <Empty description="No chains found" />
        ) : (
          <div className="flex flex-col">
            {filteredChains.map((chain) => (
              <button
                key={chain.enum}
                className={clsx(
                  'flex items-center gap-3 px-3 py-3 rounded-xl',
                  'transition-colors min-h-[44px]',
                  chain.enum === value || chain.serverId === value
                    ? 'bg-[var(--r-blue-light-1)]'
                    : 'hover:bg-[var(--r-neutral-bg-2)]'
                )}
                onClick={() => handleSelect(chain)}
              >
                <ChainIcon chain={chain} size="md" />
                <div className="flex flex-col items-start flex-1 min-w-0">
                  <span className="text-sm font-medium text-[var(--r-neutral-title-1)]">
                    {chain.name}
                  </span>
                  <span className="text-xs text-[var(--r-neutral-foot)]">
                    {chain.nativeTokenSymbol}
                  </span>
                </div>
                {(chain.enum === value || chain.serverId === value) && (
                  <CheckIcon />
                )}
              </button>
            ))}
          </div>
        )}
      </Popup>
    </>
  );
};

const ArrowDownIcon = () => (
  <svg width="16" height="16" viewBox="0 0 16 16" fill="none" className="text-[var(--r-neutral-foot)]">
    <path d="M4 6l4 4 4-4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

const SearchIcon = () => (
  <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
    <circle cx="7" cy="7" r="5" stroke="currentColor" strokeWidth="1.5" />
    <path d="M11 11l3 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
  </svg>
);

const CheckIcon = () => (
  <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
    <path d="M4 9l4 4 6-7" stroke="var(--rabby-brand)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);
