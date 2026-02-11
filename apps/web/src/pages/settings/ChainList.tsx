import { useState, useMemo, useCallback } from 'react';
import { useChainContext } from '../../contexts/ChainContext';
import type { Chain } from '@rabby/shared';

export default function ChainList() {
  const { chains, loading } = useChainContext();
  const [search, setSearch] = useState('');
  const [enabledChains, setEnabledChains] = useState<Set<number>>(() => {
    return new Set(chains.map((c) => c.id));
  });

  // Initialize enabled set when chains load
  useMemo(() => {
    if (chains.length > 0 && enabledChains.size === 0) {
      setEnabledChains(new Set(chains.map((c) => c.id)));
    }
  }, [chains, enabledChains.size]);

  const filteredChains = useMemo(() => {
    if (!search.trim()) return chains;
    const q = search.trim().toLowerCase();
    return chains.filter(
      (c) =>
        c.name.toLowerCase().includes(q) ||
        c.nativeTokenSymbol.toLowerCase().includes(q) ||
        c.enum.toLowerCase().includes(q)
    );
  }, [chains, search]);

  const toggleChain = useCallback((chainId: number) => {
    setEnabledChains((prev) => {
      const next = new Set(prev);
      if (next.has(chainId)) {
        next.delete(chainId);
      } else {
        next.add(chainId);
      }
      return next;
    });
  }, []);

  const enableAll = useCallback(() => {
    setEnabledChains(new Set(chains.map((c) => c.id)));
  }, [chains]);

  const disableAll = useCallback(() => {
    setEnabledChains(new Set());
  }, []);

  const enabledCount = filteredChains.filter((c) => enabledChains.has(c.id)).length;

  // Get a deterministic color for chain icon placeholder
  const getChainColor = (chain: Chain): string => {
    const colors = [
      '#627eea', '#f3ba2f', '#8247e5', '#e84142',
      '#2b6def', '#28a0f0', '#ff0420', '#0052ff',
    ];
    return colors[chain.id % colors.length];
  };

  if (loading) {
    return (
      <div
        style={{
          maxWidth: 780,
          margin: '0 auto',
          padding: '60px 20px',
          textAlign: 'center',
        }}
      >
        <div
          style={{
            width: 40,
            height: 40,
            border: '3px solid var(--r-neutral-line, #e5e9ef)',
            borderTopColor: 'var(--r-blue-default, #4c65ff)',
            borderRadius: '50%',
            animation: 'spin 0.8s linear infinite',
            margin: '0 auto 16px',
          }}
        />
        <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
        <p style={{ fontSize: 14, color: 'var(--r-neutral-foot, #6a7587)' }}>
          Loading chains...
        </p>
      </div>
    );
  }

  return (
    <div style={{ maxWidth: 780, margin: '0 auto', padding: '0 20px' }}>
      {/* Header */}
      <div style={{ marginBottom: 24 }}>
        <h2
          style={{
            margin: 0,
            fontSize: 24,
            fontWeight: 600,
            color: 'var(--r-neutral-title-1, #192945)',
          }}
        >
          Chain List
        </h2>
        <p
          style={{
            margin: '6px 0 0',
            fontSize: 14,
            color: 'var(--r-neutral-foot, #6a7587)',
          }}
        >
          {enabledCount} of {chains.length} chains enabled
        </p>
      </div>

      {/* Search + bulk actions */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 12,
          marginBottom: 16,
        }}
      >
        {/* Search input */}
        <div style={{ flex: 1, position: 'relative' }}>
          <svg
            width="16"
            height="16"
            viewBox="0 0 16 16"
            fill="none"
            style={{
              position: 'absolute',
              left: 12,
              top: '50%',
              transform: 'translateY(-50%)',
              color: 'var(--r-neutral-foot, #6a7587)',
            }}
          >
            <path
              d="M7.333 12.667A5.333 5.333 0 1 0 7.333 2a5.333 5.333 0 0 0 0 10.667ZM14 14l-2.9-2.9"
              stroke="currentColor"
              strokeWidth="1.2"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
          <input
            type="text"
            placeholder="Search chains..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            style={{
              width: '100%',
              padding: '10px 12px 10px 36px',
              background: 'var(--r-neutral-card-1, #fff)',
              border: '1px solid var(--r-neutral-line, #e5e9ef)',
              borderRadius: 8,
              fontSize: 14,
              color: 'var(--r-neutral-title-1, #192945)',
              outline: 'none',
              boxSizing: 'border-box',
            }}
          />
        </div>

        {/* Enable All */}
        <button
          onClick={enableAll}
          style={{
            padding: '10px 16px',
            background: 'var(--r-blue-default, #4c65ff)',
            color: '#fff',
            border: 'none',
            borderRadius: 8,
            fontSize: 13,
            fontWeight: 500,
            cursor: 'pointer',
            whiteSpace: 'nowrap',
          }}
        >
          Enable All
        </button>

        {/* Disable All */}
        <button
          onClick={disableAll}
          style={{
            padding: '10px 16px',
            background: 'var(--r-neutral-card-2, #f2f4f7)',
            color: 'var(--r-neutral-foot, #6a7587)',
            border: 'none',
            borderRadius: 8,
            fontSize: 13,
            fontWeight: 500,
            cursor: 'pointer',
            whiteSpace: 'nowrap',
          }}
        >
          Disable All
        </button>
      </div>

      {/* Chain list */}
      <div
        style={{
          background: 'var(--r-neutral-card-1, #fff)',
          borderRadius: 16,
          overflow: 'hidden',
        }}
      >
        {filteredChains.length === 0 ? (
          <div
            style={{
              padding: '40px 20px',
              textAlign: 'center',
              color: 'var(--r-neutral-foot, #6a7587)',
              fontSize: 14,
            }}
          >
            {search
              ? `No chains found matching "${search}"`
              : 'No chains available'}
          </div>
        ) : (
          filteredChains.map((chain, index) => {
            const enabled = enabledChains.has(chain.id);
            return (
              <div
                key={chain.id}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  padding: '14px 20px',
                  gap: 14,
                  borderBottom:
                    index < filteredChains.length - 1
                      ? '1px solid var(--r-neutral-line, #e5e9ef)'
                      : 'none',
                  opacity: enabled ? 1 : 0.5,
                  transition: 'opacity 0.2s',
                }}
              >
                {/* Chain icon placeholder */}
                <div
                  style={{
                    width: 36,
                    height: 36,
                    borderRadius: '50%',
                    background: getChainColor(chain),
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: 15,
                    fontWeight: 700,
                    color: '#fff',
                    flexShrink: 0,
                  }}
                >
                  {chain.name[0]}
                </div>

                {/* Chain info */}
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div
                    style={{
                      fontSize: 14,
                      fontWeight: 500,
                      color: 'var(--r-neutral-title-1, #192945)',
                    }}
                  >
                    {chain.name}
                  </div>
                  <div
                    style={{
                      fontSize: 12,
                      color: 'var(--r-neutral-foot, #6a7587)',
                      marginTop: 2,
                    }}
                  >
                    {chain.nativeTokenSymbol}
                    {chain.isTestnet && (
                      <span
                        style={{
                          marginLeft: 8,
                          fontSize: 10,
                          padding: '1px 6px',
                          borderRadius: 4,
                          background: 'rgba(245,166,35,0.12)',
                          color: '#f5a623',
                          fontWeight: 500,
                        }}
                      >
                        Testnet
                      </span>
                    )}
                  </div>
                </div>

                {/* Toggle switch */}
                <button
                  onClick={() => toggleChain(chain.id)}
                  role="switch"
                  aria-checked={enabled}
                  style={{
                    width: 44,
                    height: 24,
                    borderRadius: 12,
                    border: 'none',
                    background: enabled
                      ? 'var(--r-blue-default, #4c65ff)'
                      : 'var(--r-neutral-line, #d3d8e0)',
                    cursor: 'pointer',
                    position: 'relative',
                    transition: 'background 0.2s',
                    flexShrink: 0,
                    padding: 0,
                  }}
                >
                  <div
                    style={{
                      width: 20,
                      height: 20,
                      borderRadius: '50%',
                      background: '#fff',
                      position: 'absolute',
                      top: 2,
                      left: enabled ? 22 : 2,
                      transition: 'left 0.2s',
                      boxShadow: '0 1px 3px rgba(0,0,0,0.15)',
                    }}
                  />
                </button>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}
