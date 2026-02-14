import React, { useState, useMemo, useCallback } from 'react';
import clsx from 'clsx';
import { PageHeader } from '../../components/layout';
import { Input, Empty } from '../../components/ui';
import { ChainIcon } from '../../components/chain';
import { useChain, usePreference } from '../../hooks';
import type { Chain } from '@rabby/shared';

// ---------------------------------------------------------------------------
// Chain List Page
// ---------------------------------------------------------------------------
const ChainListPage: React.FC = () => {
  const {
    mainnetList,
    testnetList,
    pinnedChains,
    addPinnedChain,
    removePinnedChain,
    customRPCs,
  } = useChain();
  const { isShowTestnet, setShowTestnet } = usePreference();

  const [search, setSearch] = useState('');

  const chains = useMemo(() => {
    const all = isShowTestnet ? [...mainnetList, ...testnetList] : mainnetList;
    if (!search.trim()) return all;
    const q = search.toLowerCase();
    return all.filter(
      (c) =>
        c.name.toLowerCase().includes(q) ||
        c.enum.toLowerCase().includes(q) ||
        c.nativeTokenSymbol.toLowerCase().includes(q)
    );
  }, [mainnetList, testnetList, isShowTestnet, search]);

  const togglePinned = useCallback(
    (chain: Chain) => {
      if (pinnedChains.includes(chain.enum)) {
        removePinnedChain(chain.enum);
      } else {
        addPinnedChain(chain.enum);
      }
    },
    [pinnedChains, addPinnedChain, removePinnedChain]
  );

  return (
    <div className="min-h-screen bg-[var(--r-neutral-bg-1)] flex flex-col">
      <PageHeader
        title={`Supported Chains (${chains.length})`}
      />

      {/* Search + Testnet toggle */}
      <div className="px-4 pb-3 flex flex-col gap-3">
        <Input
          placeholder="Search chains..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          prefix={<SearchIcon />}
        />

        {/* Testnet toggle */}
        <div className="flex items-center justify-between bg-[var(--r-neutral-card-1)] rounded-xl px-4 py-3">
          <span className="text-sm text-[var(--r-neutral-title-1)]">
            Show Testnets
          </span>
          <ToggleSwitch
            checked={isShowTestnet}
            onChange={setShowTestnet}
          />
        </div>
      </div>

      {/* Chain list */}
      <div className="flex-1 overflow-y-auto px-4 pb-4">
        {chains.length === 0 ? (
          <Empty description="No chains found" />
        ) : (
          <div className="bg-[var(--r-neutral-card-1)] rounded-xl overflow-hidden divide-y divide-[var(--r-neutral-line)]">
            {chains.map((chain) => {
              const isPinned = pinnedChains.includes(chain.enum);
              const hasCustomRPC = !!customRPCs[chain.enum];

              return (
                <div
                  key={chain.enum}
                  className="flex items-center gap-3 px-4 py-3 min-h-[52px]"
                >
                  {/* Drag handle placeholder */}
                  <div className="flex-shrink-0 text-[var(--r-neutral-line)] cursor-grab">
                    <DragIcon />
                  </div>

                  {/* Chain icon + info */}
                  <ChainIcon chain={chain} size="md" />
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-1.5">
                      <span className="text-sm font-medium text-[var(--r-neutral-title-1)] truncate">
                        {chain.name}
                      </span>
                      {chain.isTestnet && (
                        <span className="text-[10px] px-1.5 py-0.5 rounded bg-orange-100 text-orange-600 font-medium">
                          Testnet
                        </span>
                      )}
                      {hasCustomRPC && (
                        <span className="text-[10px] px-1.5 py-0.5 rounded bg-blue-100 text-blue-600 font-medium">
                          Custom RPC
                        </span>
                      )}
                    </div>
                    <span className="text-xs text-[var(--r-neutral-foot)]">
                      {chain.nativeTokenSymbol}
                    </span>
                  </div>

                  {/* Pin toggle */}
                  <button
                    className={clsx(
                      'p-2 min-w-[44px] min-h-[44px] flex items-center justify-center flex-shrink-0',
                      isPinned
                        ? 'text-[var(--rabby-brand)]'
                        : 'text-[var(--r-neutral-foot)]'
                    )}
                    onClick={() => togglePinned(chain)}
                  >
                    <PinIcon filled={isPinned} />
                  </button>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
};

export default ChainListPage;

// ---------------------------------------------------------------------------
// Toggle Switch
// ---------------------------------------------------------------------------
interface ToggleSwitchProps {
  checked: boolean;
  onChange: (value: boolean) => void;
}

const ToggleSwitch: React.FC<ToggleSwitchProps> = ({ checked, onChange }) => (
  <button
    role="switch"
    aria-checked={checked}
    className={clsx(
      'relative w-11 h-6 rounded-full transition-colors flex-shrink-0',
      checked ? 'bg-[var(--rabby-brand)]' : 'bg-[var(--r-neutral-line)]'
    )}
    onClick={() => onChange(!checked)}
  >
    <div
      className={clsx(
        'absolute top-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform',
        checked ? 'translate-x-[22px]' : 'translate-x-0.5'
      )}
    />
  </button>
);

// ---------------------------------------------------------------------------
// Icons
// ---------------------------------------------------------------------------
const SearchIcon = () => (
  <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
    <circle cx="7" cy="7" r="5" stroke="currentColor" strokeWidth="1.5" />
    <path d="M11 11l3 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
  </svg>
);

const DragIcon = () => (
  <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
    <circle cx="5" cy="3" r="1" fill="currentColor" />
    <circle cx="9" cy="3" r="1" fill="currentColor" />
    <circle cx="5" cy="7" r="1" fill="currentColor" />
    <circle cx="9" cy="7" r="1" fill="currentColor" />
    <circle cx="5" cy="11" r="1" fill="currentColor" />
    <circle cx="9" cy="11" r="1" fill="currentColor" />
  </svg>
);

const PinIcon: React.FC<{ filled: boolean }> = ({ filled }) => (
  <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
    <path
      d="M10 2L6 6l-3 1 4 4 1-3 4-4-2-2z"
      stroke="currentColor"
      strokeWidth="1.3"
      strokeLinejoin="round"
      fill={filled ? 'currentColor' : 'none'}
    />
    <path d="M4 12l2.5-2.5" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
  </svg>
);
