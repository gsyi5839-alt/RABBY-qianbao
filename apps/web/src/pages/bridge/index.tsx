import React, { useState, useCallback, useMemo } from 'react';
import type { BridgeQuote } from '@rabby/shared';
import { useWallet } from '../../contexts/WalletContext';
import { useChainContext } from '../../contexts/ChainContext';
import { useTokenList } from '../../hooks/useTokenList';

/* ─── Constants ─── */

const SUPPORTED_CHAINS = [
  { id: 'eth', name: 'Ethereum', logo: '', color: '#627eea' },
  { id: 'arb', name: 'Arbitrum', logo: '', color: '#28a0f0' },
  { id: 'op', name: 'Optimism', logo: '', color: '#ff0420' },
  { id: 'polygon', name: 'Polygon', logo: '', color: '#8247e5' },
  { id: 'bsc', name: 'BSC', logo: '', color: '#f0b90b' },
  { id: 'base', name: 'Base', logo: '', color: '#0052ff' },
  { id: 'avax', name: 'Avalanche', logo: '', color: '#e84142' },
];

const MOCK_TOKENS = [
  { id: '0xeeee-eth', chain: 'eth', name: 'Ethereum', symbol: 'ETH', decimals: 18, logo_url: '', price: 3420.50, amount: 2.45, is_verified: true, is_core: true },
  { id: '0xa0b8-usdc', chain: 'eth', name: 'USD Coin', symbol: 'USDC', decimals: 6, logo_url: '', price: 1.0, amount: 5240.00, is_verified: true, is_core: true },
  { id: '0xdac1-usdt', chain: 'eth', name: 'Tether', symbol: 'USDT', decimals: 6, logo_url: '', price: 1.0, amount: 3100.00, is_verified: true, is_core: true },
  { id: '0x6b17-dai', chain: 'eth', name: 'Dai', symbol: 'DAI', decimals: 18, logo_url: '', price: 1.0, amount: 1890.00, is_verified: true, is_core: true },
  { id: '0x2260-wbtc', chain: 'eth', name: 'Wrapped BTC', symbol: 'WBTC', decimals: 8, logo_url: '', price: 97250.00, amount: 0.085, is_verified: true, is_core: true },
];

function generateMockQuotes(
  fromAmount: string,
  fromToken: typeof MOCK_TOKENS[0] | null,
  toChain: typeof SUPPORTED_CHAINS[0],
): BridgeQuote[] {
  if (!fromToken || !fromAmount || Number(fromAmount) <= 0) return [];
  const amt = Number(fromAmount);

  return [
    {
      bridge_id: 'across',
      bridge_name: 'Across',
      from_chain_id: 'eth',
      to_chain_id: toChain.id,
      from_token: fromToken as any,
      to_token: { ...fromToken, chain: toChain.id } as any,
      from_token_amount: fromAmount,
      to_token_amount: String(amt * 0.998),
      fee_token_amount: String(amt * 0.002),
      duration: 120,
    },
    {
      bridge_id: 'stargate',
      bridge_name: 'Stargate',
      from_chain_id: 'eth',
      to_chain_id: toChain.id,
      from_token: fromToken as any,
      to_token: { ...fromToken, chain: toChain.id } as any,
      from_token_amount: fromAmount,
      to_token_amount: String(amt * 0.995),
      fee_token_amount: String(amt * 0.005),
      duration: 300,
    },
    {
      bridge_id: 'celer',
      bridge_name: 'Celer',
      from_chain_id: 'eth',
      to_chain_id: toChain.id,
      from_token: fromToken as any,
      to_token: { ...fromToken, chain: toChain.id } as any,
      from_token_amount: fromAmount,
      to_token_amount: String(amt * 0.993),
      fee_token_amount: String(amt * 0.007),
      duration: 600,
    },
  ];
}

/* ─── Helpers ─── */

function formatUsd(value: number): string {
  return value.toLocaleString('en-US', { style: 'currency', currency: 'USD' });
}

function truncateAmount(value: number, decimals = 6): string {
  return value.toFixed(decimals).replace(/\.?0+$/, '') || '0';
}

function formatDuration(seconds: number): string {
  if (seconds < 60) return `~${seconds}s`;
  const m = Math.round(seconds / 60);
  return `~${m} min`;
}

/* ─── Inline sub-components ─── */

function TokenIcon({ symbol, logoUrl, size = 32, color }: { symbol?: string; logoUrl?: string; size?: number; color?: string }) {
  if (logoUrl) {
    return (
      <img
        src={logoUrl}
        alt={symbol}
        style={{ width: size, height: size, borderRadius: '50%' }}
        onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
      />
    );
  }
  return (
    <div style={{
      width: size, height: size, borderRadius: '50%',
      background: color || 'var(--r-blue-light-1, #edf0ff)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontSize: size * 0.4, fontWeight: 700,
      color: color ? '#fff' : 'var(--r-blue-default, #4c65ff)',
    }}>
      {symbol?.[0] ?? '?'}
    </div>
  );
}

function ChainBadge({ chain, size = 28 }: { chain: typeof SUPPORTED_CHAINS[0]; size?: number }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: '50%',
      background: chain.color,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontSize: size * 0.38, fontWeight: 700, color: '#fff',
    }}>
      {chain.name[0]}
    </div>
  );
}

/* ─── Main Bridge Page ─── */

export default function BridgePage() {
  const { currentAccount, sendTransaction } = useWallet();
  const { currentChain } = useChainContext();
  const { tokens: walletTokens } = useTokenList(currentChain?.serverId);

  const tokens = walletTokens.length > 0 ? walletTokens : MOCK_TOKENS as any[];

  /* State */
  const [fromChain, setFromChain] = useState(SUPPORTED_CHAINS[0]);
  const [toChain, setToChain] = useState(SUPPORTED_CHAINS[1]);
  const [fromToken, setFromToken] = useState<typeof MOCK_TOKENS[0] | null>(null);
  const [fromAmount, setFromAmount] = useState('');
  const [selectedQuote, setSelectedQuote] = useState<BridgeQuote | null>(null);
  const [confirmVisible, setConfirmVisible] = useState(false);
  const [bridging, setBridging] = useState(false);
  const [chainPickerFor, setChainPickerFor] = useState<'from' | 'to' | null>(null);
  const [tokenPickerOpen, setTokenPickerOpen] = useState(false);
  const [tokenSearch, setTokenSearch] = useState('');
  const [quotesLoading, setQuotesLoading] = useState(false);
  const [showFeeBreakdown, setShowFeeBreakdown] = useState(false);

  /* Quotes */
  const quotes = useMemo(() => {
    if (!fromToken || !fromAmount || Number(fromAmount) <= 0) return [];
    return generateMockQuotes(fromAmount, fromToken, toChain);
  }, [fromAmount, fromToken, toChain]);

  // Auto-select best quote when quotes change
  React.useEffect(() => {
    if (quotes.length > 0) {
      setSelectedQuote(quotes[0]);
    } else {
      setSelectedQuote(null);
    }
  }, [quotes]);

  // Simulate loading
  React.useEffect(() => {
    if (fromToken && fromAmount && Number(fromAmount) > 0) {
      setQuotesLoading(true);
      const timer = setTimeout(() => setQuotesLoading(false), 800);
      return () => clearTimeout(timer);
    }
    setQuotesLoading(false);
  }, [fromAmount, fromToken, toChain]);

  /* Handlers */
  const handleSwapChains = useCallback(() => {
    setFromChain(toChain);
    setToChain(fromChain);
    setSelectedQuote(null);
  }, [fromChain, toChain]);

  const handleBridge = useCallback(() => {
    if (!selectedQuote) return;
    setConfirmVisible(true);
  }, [selectedQuote]);

  const handleConfirmBridge = useCallback(async () => {
    if (!selectedQuote || !currentAccount) return;
    setBridging(true);
    try {
      // Simulate bridge transaction
      await new Promise((r) => setTimeout(r, 2000));
      if (selectedQuote.tx) {
        await sendTransaction(selectedQuote.tx);
      }
      setConfirmVisible(false);
      setFromAmount('');
      setSelectedQuote(null);
    } catch {
      // error handled
    } finally {
      setBridging(false);
    }
  }, [selectedQuote, currentAccount, sendTransaction]);

  /* Derived state */
  const toAmount = selectedQuote ? truncateAmount(Number(selectedQuote.to_token_amount)) : '';
  const fromUsd = fromToken && fromAmount ? formatUsd(Number(fromAmount) * fromToken.price) : '';
  const toUsd = selectedQuote && fromToken
    ? formatUsd(Number(selectedQuote.to_token_amount) * fromToken.price)
    : '';
  const feeAmount = selectedQuote?.fee_token_amount ? Number(selectedQuote.fee_token_amount) : 0;
  const feeUsd = feeAmount && fromToken ? formatUsd(feeAmount * fromToken.price) : '';

  /* Button state */
  let buttonLabel = 'Bridge';
  let buttonDisabled = false;
  if (!fromToken) {
    buttonLabel = 'Select Token';
    buttonDisabled = true;
  } else if (!fromAmount || Number(fromAmount) <= 0) {
    buttonLabel = 'Enter Amount';
    buttonDisabled = true;
  } else if (fromToken && Number(fromAmount) > fromToken.amount) {
    buttonLabel = 'Insufficient Balance';
    buttonDisabled = true;
  } else if (fromChain.id === toChain.id) {
    buttonLabel = 'Select Different Chains';
    buttonDisabled = true;
  } else if (quotesLoading) {
    buttonLabel = 'Finding Best Route...';
    buttonDisabled = true;
  } else if (!selectedQuote) {
    buttonLabel = 'No Routes Available';
    buttonDisabled = true;
  }

  /* Filtered tokens for picker */
  const filteredTokens = useMemo(() => {
    if (!tokenSearch) return tokens;
    const q = tokenSearch.toLowerCase();
    return tokens.filter(
      (t: any) =>
        t.symbol.toLowerCase().includes(q) ||
        t.name.toLowerCase().includes(q) ||
        t.id.toLowerCase().includes(q),
    );
  }, [tokens, tokenSearch]);

  /* ─── Styles ─── */
  const cardStyle: React.CSSProperties = {
    background: 'var(--r-neutral-card-1, #fff)',
    borderRadius: 16,
    boxShadow: 'var(--rabby-shadow-sm, 0 2px 4px rgba(0,0,0,0.04))',
  };

  const tokenInputCardStyle: React.CSSProperties = {
    ...cardStyle,
    padding: '16px 20px',
  };

  /* ─── Chain Picker Modal ─── */
  const renderChainPicker = () => {
    if (!chainPickerFor) return null;
    const currentSelection = chainPickerFor === 'from' ? fromChain : toChain;
    const otherChain = chainPickerFor === 'from' ? toChain : fromChain;
    return (
      <div style={{
        position: 'fixed', inset: 0, zIndex: 1000,
        background: 'rgba(0,0,0,0.4)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}
        onClick={() => setChainPickerFor(null)}
      >
        <div
          style={{
            background: 'var(--r-neutral-bg-1, #f7f8fa)',
            borderRadius: 20, width: 400, maxHeight: '60vh',
            display: 'flex', flexDirection: 'column',
            boxShadow: '0 20px 60px rgba(0,0,0,0.15)',
          }}
          onClick={(e) => e.stopPropagation()}
        >
          <div style={{ padding: '20px 20px 12px', borderBottom: '1px solid var(--r-neutral-line, #e0e5ec)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontWeight: 600, fontSize: 16, color: 'var(--r-neutral-title-1, #192945)' }}>
                Select {chainPickerFor === 'from' ? 'Source' : 'Destination'} Chain
              </span>
              <button
                onClick={() => setChainPickerFor(null)}
                style={{ background: 'none', border: 'none', fontSize: 20, cursor: 'pointer', color: 'var(--r-neutral-foot, #6a7587)' }}
              >
                &times;
              </button>
            </div>
          </div>
          <div style={{ overflowY: 'auto', flex: 1, padding: '8px 0' }}>
            {SUPPORTED_CHAINS.map((chain) => {
              const isSelected = currentSelection.id === chain.id;
              const isOther = otherChain.id === chain.id;
              return (
                <button
                  key={chain.id}
                  disabled={isOther}
                  onClick={() => {
                    if (chainPickerFor === 'from') {
                      setFromChain(chain);
                    } else {
                      setToChain(chain);
                    }
                    setSelectedQuote(null);
                    setChainPickerFor(null);
                  }}
                  style={{
                    display: 'flex', alignItems: 'center', gap: 12,
                    width: '100%', padding: '12px 20px',
                    background: isSelected ? 'var(--r-blue-light-1, #edf0ff)' : 'transparent',
                    border: 'none', cursor: isOther ? 'not-allowed' : 'pointer',
                    textAlign: 'left', opacity: isOther ? 0.4 : 1,
                  }}
                >
                  <ChainBadge chain={chain} size={36} />
                  <div style={{ flex: 1 }}>
                    <div style={{
                      fontWeight: 600, fontSize: 14,
                      color: isSelected ? 'var(--r-blue-default, #4c65ff)' : 'var(--r-neutral-title-1, #192945)',
                    }}>
                      {chain.name}
                    </div>
                  </div>
                  {isSelected && (
                    <div style={{
                      width: 20, height: 20, borderRadius: '50%',
                      background: 'var(--r-blue-default, #4c65ff)',
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      color: '#fff', fontSize: 12,
                    }}>
                      &#10003;
                    </div>
                  )}
                </button>
              );
            })}
          </div>
        </div>
      </div>
    );
  };

  /* ─── Token Picker Modal ─── */
  const renderTokenPicker = () => {
    if (!tokenPickerOpen) return null;
    return (
      <div style={{
        position: 'fixed', inset: 0, zIndex: 1000,
        background: 'rgba(0,0,0,0.4)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}
        onClick={() => { setTokenPickerOpen(false); setTokenSearch(''); }}
      >
        <div
          style={{
            background: 'var(--r-neutral-bg-1, #f7f8fa)',
            borderRadius: 20, width: 400, maxHeight: '70vh',
            display: 'flex', flexDirection: 'column',
            boxShadow: '0 20px 60px rgba(0,0,0,0.15)',
          }}
          onClick={(e) => e.stopPropagation()}
        >
          <div style={{ padding: '20px 20px 12px', borderBottom: '1px solid var(--r-neutral-line, #e0e5ec)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
              <span style={{ fontWeight: 600, fontSize: 16, color: 'var(--r-neutral-title-1, #192945)' }}>
                Select Token
              </span>
              <button
                onClick={() => { setTokenPickerOpen(false); setTokenSearch(''); }}
                style={{ background: 'none', border: 'none', fontSize: 20, cursor: 'pointer', color: 'var(--r-neutral-foot, #6a7587)' }}
              >
                &times;
              </button>
            </div>
            <input
              type="text"
              placeholder="Search by name or address"
              value={tokenSearch}
              onChange={(e) => setTokenSearch(e.target.value)}
              autoFocus
              style={{
                width: '100%', padding: '10px 14px', borderRadius: 10,
                border: '1px solid var(--r-neutral-line, #e0e5ec)',
                background: 'var(--r-neutral-card-1, #fff)',
                fontSize: 14, outline: 'none',
                boxSizing: 'border-box',
              }}
            />
          </div>
          <div style={{ overflowY: 'auto', flex: 1, padding: '8px 0' }}>
            {filteredTokens.length === 0 ? (
              <div style={{ textAlign: 'center', padding: 32, color: 'var(--r-neutral-foot, #6a7587)' }}>
                No tokens found
              </div>
            ) : (
              filteredTokens.map((t: any) => (
                <button
                  key={t.id}
                  onClick={() => {
                    setFromToken(t);
                    setSelectedQuote(null);
                    setTokenPickerOpen(false);
                    setTokenSearch('');
                  }}
                  style={{
                    display: 'flex', alignItems: 'center', gap: 12,
                    width: '100%', padding: '10px 20px',
                    background: fromToken?.id === t.id ? 'var(--r-blue-light-1, #edf0ff)' : 'transparent',
                    border: 'none', cursor: 'pointer', textAlign: 'left',
                  }}
                >
                  <TokenIcon symbol={t.symbol} logoUrl={t.logo_url} size={36} />
                  <div style={{ flex: 1 }}>
                    <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--r-neutral-title-1, #192945)' }}>
                      {t.symbol}
                    </div>
                    <div style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)' }}>{t.name}</div>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <div style={{ fontSize: 14, color: 'var(--r-neutral-title-1, #192945)' }}>
                      {truncateAmount(t.amount, 4)}
                    </div>
                    <div style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)' }}>
                      {formatUsd(t.amount * t.price)}
                    </div>
                  </div>
                </button>
              ))
            )}
          </div>
        </div>
      </div>
    );
  };

  /* ─── Confirmation Modal ─── */
  const renderConfirmModal = () => {
    if (!confirmVisible || !selectedQuote) return null;
    const fAmt = Number(selectedQuote.from_token_amount);
    const tAmt = Number(selectedQuote.to_token_amount);
    const fee = selectedQuote.fee_token_amount ? Number(selectedQuote.fee_token_amount) : 0;
    return (
      <div style={{
        position: 'fixed', inset: 0, zIndex: 1000,
        background: 'rgba(0,0,0,0.4)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}
        onClick={() => !bridging && setConfirmVisible(false)}
      >
        <div
          style={{
            background: 'var(--r-neutral-card-1, #fff)',
            borderRadius: 20, width: 420, padding: 24,
            boxShadow: '0 20px 60px rgba(0,0,0,0.15)',
          }}
          onClick={(e) => e.stopPropagation()}
        >
          <div style={{ fontWeight: 600, fontSize: 18, color: 'var(--r-neutral-title-1, #192945)', marginBottom: 20, textAlign: 'center' }}>
            Confirm Bridge
          </div>

          {/* From summary */}
          <div style={{
            background: 'var(--r-neutral-bg-2, #f2f4f7)', borderRadius: 12,
            padding: '14px 16px', marginBottom: 8,
          }}>
            <div style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)', marginBottom: 6 }}>From {fromChain.name}</div>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <TokenIcon symbol={selectedQuote.from_token.symbol} logoUrl={selectedQuote.from_token.logo_url} size={28} />
                <span style={{ fontWeight: 600, fontSize: 16, color: 'var(--r-neutral-title-1, #192945)' }}>
                  {selectedQuote.from_token.symbol}
                </span>
              </div>
              <span style={{ fontSize: 20, fontWeight: 700, color: 'var(--r-neutral-title-1, #192945)' }}>
                {truncateAmount(fAmt, 6)}
              </span>
            </div>
          </div>

          <div style={{ textAlign: 'center', fontSize: 20, color: 'var(--r-neutral-foot, #6a7587)', margin: '4px 0' }}>
            &darr;
          </div>

          {/* To summary */}
          <div style={{
            background: 'var(--r-neutral-bg-2, #f2f4f7)', borderRadius: 12,
            padding: '14px 16px', marginBottom: 20,
          }}>
            <div style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)', marginBottom: 6 }}>To {toChain.name}</div>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <TokenIcon symbol={selectedQuote.to_token.symbol} logoUrl={selectedQuote.to_token.logo_url} size={28} />
                <span style={{ fontWeight: 600, fontSize: 16, color: 'var(--r-neutral-title-1, #192945)' }}>
                  {selectedQuote.to_token.symbol}
                </span>
              </div>
              <span style={{ fontSize: 20, fontWeight: 700, color: 'var(--r-green-default, #27c193)' }}>
                {truncateAmount(tAmt, 6)}
              </span>
            </div>
          </div>

          {/* Details */}
          <div style={{
            background: 'var(--r-neutral-bg-2, #f2f4f7)', borderRadius: 12,
            padding: '12px 16px', marginBottom: 20,
          }}>
            {[
              { label: 'Bridge', value: selectedQuote.bridge_name },
              { label: 'Bridge Fee', value: `${truncateAmount(fee, 6)} ${selectedQuote.from_token.symbol} (${fromToken ? formatUsd(fee * fromToken.price) : ''})` },
              ...(selectedQuote.duration
                ? [{ label: 'Est. Time', value: formatDuration(selectedQuote.duration) }]
                : []),
              { label: 'You Receive', value: `${truncateAmount(tAmt, 6)} ${selectedQuote.to_token.symbol}` },
            ].map((row) => (
              <div key={row.label} style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0' }}>
                <span style={{ fontSize: 13, color: 'var(--r-neutral-foot, #6a7587)' }}>{row.label}</span>
                <span style={{ fontSize: 13, fontWeight: 500, color: 'var(--r-neutral-title-1, #192945)' }}>{row.value}</span>
              </div>
            ))}
          </div>

          {/* Buttons */}
          <div style={{ display: 'flex', gap: 12 }}>
            <button
              onClick={() => setConfirmVisible(false)}
              disabled={bridging}
              style={{
                flex: 1, padding: '14px 0', borderRadius: 12,
                border: '1px solid var(--r-neutral-line, #e0e5ec)',
                background: 'transparent', fontSize: 15, fontWeight: 600,
                cursor: bridging ? 'not-allowed' : 'pointer',
                color: 'var(--r-neutral-title-1, #192945)',
              }}
            >
              Cancel
            </button>
            <button
              onClick={handleConfirmBridge}
              disabled={bridging}
              style={{
                flex: 1, padding: '14px 0', borderRadius: 12,
                border: 'none',
                background: bridging ? 'var(--r-neutral-foot, #6a7587)' : 'var(--r-blue-default, #4c65ff)',
                fontSize: 15, fontWeight: 600,
                cursor: bridging ? 'not-allowed' : 'pointer',
                color: '#fff',
              }}
            >
              {bridging ? 'Bridging...' : 'Confirm Bridge'}
            </button>
          </div>
        </div>
      </div>
    );
  };

  /* ─── Render ─── */
  return (
    <div style={{ maxWidth: 480, margin: '0 auto' }}>
      <h2 style={{
        fontSize: 20, fontWeight: 600, margin: '0 0 24px',
        color: 'var(--r-neutral-title-1, #192945)',
      }}>
        Bridge
      </h2>

      {/* ─── Source: Chain + Token + Amount ─── */}
      <div style={tokenInputCardStyle}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
          <span style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)' }}>From</span>
          {fromToken && (
            <span style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)' }}>
              Balance: {truncateAmount(fromToken.amount, 4)} {fromToken.symbol}
            </span>
          )}
        </div>

        {/* Chain selector */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12 }}>
          <button
            onClick={() => setChainPickerFor('from')}
            style={{
              display: 'flex', alignItems: 'center', gap: 8,
              padding: '6px 12px 6px 8px', borderRadius: 20,
              background: 'var(--r-neutral-bg-2, #f2f4f7)',
              border: 'none', cursor: 'pointer',
            }}
          >
            <ChainBadge chain={fromChain} size={22} />
            <span style={{ fontWeight: 600, fontSize: 13, color: 'var(--r-neutral-title-1, #192945)' }}>
              {fromChain.name}
            </span>
            <span style={{ fontSize: 10, color: 'var(--r-neutral-foot, #6a7587)' }}>&darr;</span>
          </button>
        </div>

        {/* Token + Amount row */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <button
            onClick={() => setTokenPickerOpen(true)}
            style={{
              display: 'flex', alignItems: 'center', gap: 8,
              padding: '8px 12px', borderRadius: 20,
              background: 'var(--r-neutral-bg-2, #f2f4f7)',
              border: 'none', cursor: 'pointer',
              flexShrink: 0,
            }}
          >
            <TokenIcon
              symbol={fromToken?.symbol}
              logoUrl={fromToken?.logo_url}
              size={24}
            />
            <span style={{ fontWeight: 600, fontSize: 15, color: 'var(--r-neutral-title-1, #192945)' }}>
              {fromToken ? fromToken.symbol : 'Select'}
            </span>
            <span style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)' }}>&darr;</span>
          </button>

          <div style={{ flex: 1 }}>
            <input
              type="text"
              placeholder="0.0"
              value={fromAmount}
              onChange={(e) => {
                const val = e.target.value;
                if (/^\d*\.?\d*$/.test(val)) {
                  setFromAmount(val);
                  setSelectedQuote(null);
                }
              }}
              style={{
                width: '100%', border: 'none', background: 'transparent',
                textAlign: 'right', fontSize: 22, fontWeight: 600,
                color: 'var(--r-neutral-title-1, #192945)',
                outline: 'none', boxSizing: 'border-box',
              }}
            />
          </div>
        </div>

        {/* MAX + USD */}
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8 }}>
          <div>
            {fromToken && (
              <button
                onClick={() => {
                  setFromAmount(String(fromToken.amount));
                  setSelectedQuote(null);
                }}
                style={{
                  padding: '2px 8px', borderRadius: 4,
                  background: 'var(--r-blue-light-1, #edf0ff)',
                  color: 'var(--r-blue-default, #4c65ff)',
                  border: 'none', fontSize: 11, fontWeight: 700,
                  cursor: 'pointer',
                }}
              >
                MAX
              </button>
            )}
          </div>
          <span style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)' }}>
            {fromUsd && `~${fromUsd}`}
          </span>
        </div>
      </div>

      {/* ─── Swap direction button ─── */}
      <div style={{ display: 'flex', justifyContent: 'center', margin: '-8px 0', position: 'relative', zIndex: 2 }}>
        <button
          onClick={handleSwapChains}
          style={{
            width: 40, height: 40, borderRadius: '50%',
            background: 'var(--r-neutral-card-1, #fff)',
            border: '3px solid var(--r-neutral-bg-1, #f7f8fa)',
            cursor: 'pointer',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 18, color: 'var(--r-blue-default, #4c65ff)',
            boxShadow: 'var(--rabby-shadow-sm, 0 2px 4px rgba(0,0,0,0.04))',
            transition: 'transform 200ms',
          }}
          onMouseEnter={(e) => (e.currentTarget.style.transform = 'rotate(180deg)')}
          onMouseLeave={(e) => (e.currentTarget.style.transform = 'rotate(0deg)')}
        >
          &uarr;&darr;
        </button>
      </div>

      {/* ─── Destination: Chain + Estimated Output ─── */}
      <div style={tokenInputCardStyle}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
          <span style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)' }}>To</span>
          {selectedQuote?.duration && (
            <span style={{
              fontSize: 11, color: 'var(--r-blue-default, #4c65ff)',
              background: 'var(--r-blue-light-1, #edf0ff)',
              padding: '2px 8px', borderRadius: 4, fontWeight: 600,
            }}>
              {formatDuration(selectedQuote.duration)}
            </span>
          )}
        </div>

        {/* Chain selector */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12 }}>
          <button
            onClick={() => setChainPickerFor('to')}
            style={{
              display: 'flex', alignItems: 'center', gap: 8,
              padding: '6px 12px 6px 8px', borderRadius: 20,
              background: 'var(--r-neutral-bg-2, #f2f4f7)',
              border: 'none', cursor: 'pointer',
            }}
          >
            <ChainBadge chain={toChain} size={22} />
            <span style={{ fontWeight: 600, fontSize: 13, color: 'var(--r-neutral-title-1, #192945)' }}>
              {toChain.name}
            </span>
            <span style={{ fontSize: 10, color: 'var(--r-neutral-foot, #6a7587)' }}>&darr;</span>
          </button>
        </div>

        {/* Estimated output */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 8,
            padding: '8px 12px', borderRadius: 20,
            background: 'var(--r-neutral-bg-2, #f2f4f7)',
            flexShrink: 0,
          }}>
            <TokenIcon
              symbol={fromToken?.symbol}
              logoUrl={fromToken?.logo_url}
              size={24}
            />
            <span style={{ fontWeight: 600, fontSize: 15, color: 'var(--r-neutral-title-1, #192945)' }}>
              {fromToken ? fromToken.symbol : '--'}
            </span>
          </div>

          <input
            type="text"
            placeholder="0.0"
            value={toAmount}
            readOnly
            style={{
              flex: 1, width: '100%', border: 'none', background: 'transparent',
              textAlign: 'right', fontSize: 22, fontWeight: 600,
              color: toAmount ? 'var(--r-green-default, #27c193)' : 'var(--r-neutral-foot, #6a7587)',
              outline: 'none', boxSizing: 'border-box',
            }}
          />
        </div>
        <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 8 }}>
          <span style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)' }}>
            {toUsd && `~${toUsd}`}
          </span>
        </div>
      </div>

      {/* ─── Bridge Provider Quotes ─── */}
      {(quotesLoading || quotes.length > 0) && (
        <div style={{ ...cardStyle, padding: '14px 20px', marginTop: 12 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
            <span style={{ fontSize: 13, fontWeight: 500, color: 'var(--r-neutral-body, #3e495e)' }}>
              {quotesLoading
                ? 'Finding best routes...'
                : `${quotes.length} route${quotes.length !== 1 ? 's' : ''} available`}
            </span>
          </div>

          {quotesLoading && (
            <div style={{ textAlign: 'center', padding: '12px 0' }}>
              <div style={{
                width: 20, height: 20, borderRadius: '50%',
                border: '2px solid var(--r-blue-default, #4c65ff)',
                borderTopColor: 'transparent',
                animation: 'rabby-bridge-spin 0.8s linear infinite',
                margin: '0 auto',
              }} />
              <style>{`@keyframes rabby-bridge-spin { to { transform: rotate(360deg); } }`}</style>
            </div>
          )}

          {!quotesLoading && quotes.map((quote, i) => {
            const isBest = i === 0;
            const isSelected = selectedQuote?.bridge_id === quote.bridge_id;
            const receiveAmt = Number(quote.to_token_amount);
            const fee = quote.fee_token_amount ? Number(quote.fee_token_amount) : 0;
            return (
              <button
                key={quote.bridge_id}
                onClick={() => setSelectedQuote(quote)}
                style={{
                  display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                  width: '100%', padding: '12px 14px',
                  background: isSelected
                    ? 'var(--r-blue-light-1, #edf0ff)'
                    : 'var(--r-neutral-bg-2, #f2f4f7)',
                  border: isSelected
                    ? '1.5px solid var(--r-blue-default, #4c65ff)'
                    : '1.5px solid transparent',
                  borderRadius: 12, cursor: 'pointer',
                  marginBottom: i < quotes.length - 1 ? 8 : 0,
                  textAlign: 'left',
                  transition: 'border-color 150ms, background 150ms',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  {quote.bridge_logo ? (
                    <img src={quote.bridge_logo} alt={quote.bridge_name} style={{ width: 32, height: 32, borderRadius: 8 }} />
                  ) : (
                    <div style={{
                      width: 32, height: 32, borderRadius: 8,
                      background: isSelected
                        ? 'var(--r-blue-default, #4c65ff)'
                        : 'var(--r-neutral-line, #e0e5ec)',
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      fontSize: 14, fontWeight: 700,
                      color: isSelected ? '#fff' : 'var(--r-neutral-foot, #6a7587)',
                    }}>
                      {quote.bridge_name[0]}
                    </div>
                  )}
                  <div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                      <span style={{
                        fontWeight: 600, fontSize: 14,
                        color: isSelected ? 'var(--r-blue-default, #4c65ff)' : 'var(--r-neutral-title-1, #192945)',
                      }}>
                        {quote.bridge_name}
                      </span>
                      {isBest && (
                        <span style={{
                          padding: '1px 6px', borderRadius: 4,
                          background: 'var(--r-green-light, #e8faf2)',
                          color: 'var(--r-green-default, #27c193)',
                          fontSize: 10, fontWeight: 700,
                        }}>
                          BEST
                        </span>
                      )}
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 2 }}>
                      {quote.duration && (
                        <span style={{ fontSize: 11, color: 'var(--r-neutral-foot, #6a7587)' }}>
                          {formatDuration(quote.duration)}
                        </span>
                      )}
                      <span style={{ fontSize: 11, color: 'var(--r-neutral-foot, #6a7587)' }}>
                        Fee: {truncateAmount(fee, 4)} {quote.from_token.symbol}
                      </span>
                    </div>
                  </div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div style={{
                    fontWeight: 600, fontSize: 14,
                    color: isSelected ? 'var(--r-blue-default, #4c65ff)' : 'var(--r-neutral-title-1, #192945)',
                  }}>
                    {truncateAmount(receiveAmt)} {quote.to_token.symbol}
                  </div>
                  {fromToken && (
                    <div style={{ fontSize: 11, color: 'var(--r-neutral-foot, #6a7587)' }}>
                      ~{formatUsd(receiveAmt * fromToken.price)}
                    </div>
                  )}
                </div>
              </button>
            );
          })}
        </div>
      )}

      {/* ─── Fee Breakdown Panel ─── */}
      {selectedQuote && !quotesLoading && (
        <div style={{
          ...cardStyle,
          padding: '14px 20px', marginTop: 12,
          background: 'var(--r-neutral-bg-2, #f2f4f7)',
          boxShadow: 'none',
        }}>
          <button
            onClick={() => setShowFeeBreakdown(!showFeeBreakdown)}
            style={{
              display: 'flex', justifyContent: 'space-between', alignItems: 'center',
              width: '100%', background: 'transparent', border: 'none',
              cursor: 'pointer', padding: 0,
            }}
          >
            <span style={{ fontSize: 13, fontWeight: 500, color: 'var(--r-neutral-body, #3e495e)' }}>
              Fee Details
            </span>
            <span style={{
              fontSize: 14, color: 'var(--r-neutral-foot, #6a7587)',
              transform: showFeeBreakdown ? 'rotate(90deg)' : 'rotate(0deg)',
              transition: 'transform 200ms', display: 'inline-block',
            }}>
              &rsaquo;
            </span>
          </button>

          {showFeeBreakdown && (
            <div style={{ marginTop: 10 }}>
              {[
                {
                  label: 'Bridge Fee',
                  value: `${truncateAmount(feeAmount, 6)} ${selectedQuote.from_token.symbol}`,
                  sub: feeUsd,
                },
                {
                  label: 'You Send',
                  value: `${truncateAmount(Number(selectedQuote.from_token_amount), 6)} ${selectedQuote.from_token.symbol}`,
                  sub: fromUsd,
                },
                {
                  label: 'You Receive',
                  value: `${truncateAmount(Number(selectedQuote.to_token_amount), 6)} ${selectedQuote.to_token.symbol}`,
                  sub: toUsd,
                  highlight: true,
                },
                ...(selectedQuote.duration
                  ? [{ label: 'Estimated Time', value: formatDuration(selectedQuote.duration), sub: '' }]
                  : []),
                { label: 'Route', value: `${fromChain.name} -> ${toChain.name} via ${selectedQuote.bridge_name}`, sub: '' },
              ].map((row) => (
                <div key={row.label} style={{
                  display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start',
                  padding: '5px 0',
                }}>
                  <span style={{ fontSize: 13, color: 'var(--r-neutral-foot, #6a7587)' }}>{row.label}</span>
                  <div style={{ textAlign: 'right' }}>
                    <div style={{
                      fontSize: 13, fontWeight: 500,
                      color: ('highlight' in row && row.highlight)
                        ? 'var(--r-green-default, #27c193)'
                        : 'var(--r-neutral-title-1, #192945)',
                    }}>
                      {row.value}
                    </div>
                    {row.sub && (
                      <div style={{ fontSize: 11, color: 'var(--r-neutral-foot, #6a7587)' }}>
                        ~{row.sub}
                      </div>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* ─── Bridge Button ─── */}
      <button
        onClick={handleBridge}
        disabled={buttonDisabled}
        style={{
          width: '100%', padding: '16px 0', marginTop: 16,
          borderRadius: 12, border: 'none',
          background: buttonDisabled
            ? 'var(--r-neutral-line, #e0e5ec)'
            : 'var(--r-blue-default, #4c65ff)',
          color: buttonDisabled
            ? 'var(--r-neutral-foot, #6a7587)'
            : '#fff',
          fontSize: 16, fontWeight: 600,
          cursor: buttonDisabled ? 'not-allowed' : 'pointer',
          transition: 'background 200ms, color 200ms',
        }}
      >
        {buttonLabel}
      </button>

      {/* Modals */}
      {renderChainPicker()}
      {renderTokenPicker()}
      {renderConfirmModal()}
    </div>
  );
}
