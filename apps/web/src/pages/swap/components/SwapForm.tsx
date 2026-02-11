import React, { useState, useCallback, useMemo } from 'react';
import type { TokenItem, SwapQuote } from '@rabby/shared';
import { useWallet } from '../../../contexts/WalletContext';
import { useChainContext } from '../../../contexts/ChainContext';
import { useTokenList } from '../../../hooks/useTokenList';
import { postSwap } from '../../../services/api/swap';
import { useSwapQuotes } from '../hooks/useSwapQuotes';
import { useSwapSlippage } from '../hooks/useSwapSlippage';

/* ─── helpers ─── */

const SLIPPAGE_PRESETS = [0.5, 1, 3];

function formatUsd(value: number): string {
  return value.toLocaleString('en-US', { style: 'currency', currency: 'USD' });
}

function truncateAmount(value: number, decimals = 6): string {
  return value.toFixed(decimals).replace(/\.?0+$/, '') || '0';
}

/* ─── tiny sub-components (inline) ─── */

function TokenIcon({ token, size = 32 }: { token: TokenItem | null; size?: number }) {
  if (!token) {
    return (
      <div style={{
        width: size, height: size, borderRadius: '50%',
        background: 'var(--r-neutral-line, #e0e5ec)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontSize: size * 0.4, color: 'var(--r-neutral-foot, #6a7587)',
      }}>
        ?
      </div>
    );
  }
  if (token.logo_url) {
    return (
      <img
        src={token.logo_url}
        alt={token.symbol}
        style={{ width: size, height: size, borderRadius: '50%' }}
        onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
      />
    );
  }
  return (
    <div style={{
      width: size, height: size, borderRadius: '50%',
      background: 'var(--r-blue-light-1, #edf0ff)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontSize: size * 0.4, fontWeight: 700,
      color: 'var(--r-blue-default, #4c65ff)',
    }}>
      {token.symbol?.[0] ?? '?'}
    </div>
  );
}

/* ─── main component ─── */

const SwapForm: React.FC = () => {
  const { currentAccount, sendTransaction } = useWallet();
  const { currentChain } = useChainContext();
  const { tokens } = useTokenList(currentChain?.serverId);
  const { slippage, setSlippage } = useSwapSlippage();

  const [fromToken, setFromToken] = useState<TokenItem | null>(null);
  const [toToken, setToToken] = useState<TokenItem | null>(null);
  const [fromAmount, setFromAmount] = useState('');
  const [selectedQuote, setSelectedQuote] = useState<SwapQuote | null>(null);
  const [confirmVisible, setConfirmVisible] = useState(false);
  const [swapping, setSwapping] = useState(false);
  const [customSlippage, setCustomSlippage] = useState('');
  const [showCustomSlippage, setShowCustomSlippage] = useState(false);
  const [tokenPickerFor, setTokenPickerFor] = useState<'from' | 'to' | null>(null);
  const [tokenSearch, setTokenSearch] = useState('');
  const [showQuoteList, setShowQuoteList] = useState(false);

  const { quotes, loading: quotesLoading } = useSwapQuotes(
    fromToken,
    toToken,
    fromAmount,
    currentChain?.serverId,
    slippage,
  );

  // Auto-select best quote
  React.useEffect(() => {
    if (quotes.length > 0 && !selectedQuote) {
      setSelectedQuote(quotes[0]);
    }
  }, [quotes, selectedQuote]);

  const handleSwapDirection = () => {
    setFromToken(toToken);
    setToToken(fromToken);
    setFromAmount('');
    setSelectedQuote(null);
  };

  const handleSwap = useCallback(() => {
    if (!selectedQuote) return;
    setConfirmVisible(true);
  }, [selectedQuote]);

  const handleConfirmSwap = useCallback(async () => {
    if (!selectedQuote || !currentAccount || !currentChain) return;
    setSwapping(true);
    try {
      const built = await postSwap({
        dex_id: selectedQuote.dex_id,
        from_token: selectedQuote.from_token.id,
        to_token: selectedQuote.to_token.id,
        amount: fromAmount,
        chain_id: currentChain.serverId,
        slippage: String(slippage),
        from_address: currentAccount.address,
      });
      if (built.tx) {
        await sendTransaction(built.tx);
        setConfirmVisible(false);
        setFromAmount('');
        setSelectedQuote(null);
      }
    } catch {
      // error handled silently
    } finally {
      setSwapping(false);
    }
  }, [selectedQuote, currentAccount, currentChain, fromAmount, slippage, sendTransaction]);

  /* ─── derived state ─── */

  const toAmount = selectedQuote ? truncateAmount(Number(selectedQuote.to_token_amount)) : '';
  const fromUsd = fromToken && fromAmount ? formatUsd(Number(fromAmount) * fromToken.price) : '';
  const toUsd = selectedQuote && toToken
    ? formatUsd(Number(selectedQuote.to_token_amount) * (toToken.price || 0))
    : '';

  const bestQuote = quotes[0] ?? null;

  // Quote details
  const rate = selectedQuote && Number(selectedQuote.from_token_amount) > 0
    ? Number(selectedQuote.to_token_amount) / Number(selectedQuote.from_token_amount)
    : null;
  const minReceived = selectedQuote
    ? Number(selectedQuote.to_token_amount) * (1 - slippage / 100)
    : null;

  // Button state
  let buttonLabel = 'Swap';
  let buttonDisabled = false;
  if (!fromToken || !toToken) {
    buttonLabel = 'Select Token';
    buttonDisabled = true;
  } else if (!fromAmount || Number(fromAmount) <= 0) {
    buttonLabel = 'Enter Amount';
    buttonDisabled = true;
  } else if (quotesLoading) {
    buttonLabel = 'Getting Quotes...';
    buttonDisabled = true;
  } else if (!selectedQuote) {
    buttonLabel = 'No Quotes Available';
    buttonDisabled = true;
  }

  // Filtered tokens for picker
  const filteredTokens = useMemo(() => {
    if (!tokenSearch) return tokens;
    const q = tokenSearch.toLowerCase();
    return tokens.filter(
      (t) =>
        t.symbol.toLowerCase().includes(q) ||
        t.name.toLowerCase().includes(q) ||
        t.id.toLowerCase().includes(q),
    );
  }, [tokens, tokenSearch]);

  /* ─── Inline styles ─── */
  const cardStyle: React.CSSProperties = {
    background: 'var(--r-neutral-card-1, #fff)',
    borderRadius: 16,
    boxShadow: 'var(--rabby-shadow-sm, 0 2px 4px rgba(0,0,0,0.04))',
  };

  const tokenInputCardStyle: React.CSSProperties = {
    ...cardStyle,
    padding: '16px 20px',
  };

  /* ─── Token Picker Modal ─── */
  const renderTokenPicker = () => {
    if (!tokenPickerFor) return null;
    return (
      <div style={{
        position: 'fixed', inset: 0, zIndex: 1000,
        background: 'rgba(0,0,0,0.4)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}
        onClick={() => { setTokenPickerFor(null); setTokenSearch(''); }}
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
              <span style={{ fontWeight: 600, fontSize: 16, color: 'var(--r-neutral-title-1)' }}>
                Select Token
              </span>
              <button
                onClick={() => { setTokenPickerFor(null); setTokenSearch(''); }}
                style={{ background: 'none', border: 'none', fontSize: 20, cursor: 'pointer', color: 'var(--r-neutral-foot)' }}
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
              <div style={{ textAlign: 'center', padding: 32, color: 'var(--r-neutral-foot)' }}>
                No tokens found
              </div>
            ) : (
              filteredTokens.map((t) => (
                <button
                  key={t.id}
                  onClick={() => {
                    if (tokenPickerFor === 'from') {
                      setFromToken(t);
                    } else {
                      setToToken(t);
                    }
                    setSelectedQuote(null);
                    setTokenPickerFor(null);
                    setTokenSearch('');
                  }}
                  style={{
                    display: 'flex', alignItems: 'center', gap: 12,
                    width: '100%', padding: '10px 20px',
                    background: 'transparent', border: 'none',
                    cursor: 'pointer', textAlign: 'left',
                  }}
                >
                  <TokenIcon token={t} size={36} />
                  <div style={{ flex: 1 }}>
                    <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--r-neutral-title-1)' }}>
                      {t.symbol}
                    </div>
                    <div style={{ fontSize: 12, color: 'var(--r-neutral-foot)' }}>{t.name}</div>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <div style={{ fontSize: 14, color: 'var(--r-neutral-title-1)' }}>
                      {truncateAmount(t.amount, 4)}
                    </div>
                    <div style={{ fontSize: 12, color: 'var(--r-neutral-foot)' }}>
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
    const modalRate = fAmt > 0 ? tAmt / fAmt : 0;
    const modalMin = tAmt * (1 - slippage / 100);
    return (
      <div style={{
        position: 'fixed', inset: 0, zIndex: 1000,
        background: 'rgba(0,0,0,0.4)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}
        onClick={() => !swapping && setConfirmVisible(false)}
      >
        <div
          style={{
            background: 'var(--r-neutral-card-1, #fff)',
            borderRadius: 20, width: 400, padding: 24,
            boxShadow: '0 20px 60px rgba(0,0,0,0.15)',
          }}
          onClick={(e) => e.stopPropagation()}
        >
          <div style={{ fontWeight: 600, fontSize: 18, color: 'var(--r-neutral-title-1)', marginBottom: 20, textAlign: 'center' }}>
            Confirm Swap
          </div>

          {/* From */}
          <div style={{ textAlign: 'center', marginBottom: 8 }}>
            <div style={{ fontSize: 12, color: 'var(--r-neutral-foot)', marginBottom: 4 }}>You pay</div>
            <div style={{ fontSize: 24, fontWeight: 700, color: 'var(--r-neutral-title-1)' }}>
              {fAmt.toFixed(6)} {selectedQuote.from_token.symbol}
            </div>
          </div>

          <div style={{ textAlign: 'center', fontSize: 20, color: 'var(--r-neutral-foot)', margin: '4px 0' }}>
            &darr;
          </div>

          {/* To */}
          <div style={{ textAlign: 'center', marginBottom: 20 }}>
            <div style={{ fontSize: 12, color: 'var(--r-neutral-foot)', marginBottom: 4 }}>You receive</div>
            <div style={{ fontSize: 24, fontWeight: 700, color: 'var(--r-green-default, #27c193)' }}>
              {tAmt.toFixed(6)} {selectedQuote.to_token.symbol}
            </div>
          </div>

          {/* Details */}
          <div style={{
            background: 'var(--r-neutral-bg-2, #f2f4f7)', borderRadius: 12,
            padding: '12px 16px', marginBottom: 20,
          }}>
            {[
              { label: 'Rate', value: `1 ${selectedQuote.from_token.symbol} = ${modalRate.toFixed(6)} ${selectedQuote.to_token.symbol}` },
              { label: 'Slippage', value: `${slippage}%` },
              { label: 'Min. Received', value: `${modalMin.toFixed(6)} ${selectedQuote.to_token.symbol}` },
              ...(selectedQuote.gas_fee_usd != null ? [{ label: 'Est. Gas', value: `$${selectedQuote.gas_fee_usd.toFixed(2)}` }] : []),
              { label: 'DEX', value: selectedQuote.dex_name },
            ].map((row) => (
              <div key={row.label} style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0' }}>
                <span style={{ fontSize: 13, color: 'var(--r-neutral-foot)' }}>{row.label}</span>
                <span style={{ fontSize: 13, fontWeight: 500, color: 'var(--r-neutral-title-1)' }}>{row.value}</span>
              </div>
            ))}
          </div>

          {/* Buttons */}
          <div style={{ display: 'flex', gap: 12 }}>
            <button
              onClick={() => setConfirmVisible(false)}
              disabled={swapping}
              style={{
                flex: 1, padding: '14px 0', borderRadius: 12,
                border: '1px solid var(--r-neutral-line, #e0e5ec)',
                background: 'transparent', fontSize: 15, fontWeight: 600,
                cursor: swapping ? 'not-allowed' : 'pointer',
                color: 'var(--r-neutral-title-1)',
              }}
            >
              Cancel
            </button>
            <button
              onClick={handleConfirmSwap}
              disabled={swapping}
              style={{
                flex: 1, padding: '14px 0', borderRadius: 12,
                border: 'none',
                background: swapping ? 'var(--r-neutral-foot, #6a7587)' : 'var(--r-blue-default, #4c65ff)',
                fontSize: 15, fontWeight: 600,
                cursor: swapping ? 'not-allowed' : 'pointer',
                color: '#fff',
              }}
            >
              {swapping ? 'Swapping...' : 'Confirm Swap'}
            </button>
          </div>
        </div>
      </div>
    );
  };

  /* ─── Render ─── */
  return (
    <div style={{ maxWidth: 480, margin: '0 auto' }}>
      {/* FROM token input */}
      <div style={tokenInputCardStyle}>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 10 }}>
          <span style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)' }}>From</span>
          {fromToken && (
            <span style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)' }}>
              Balance: {truncateAmount(fromToken.amount, 4)} {fromToken.symbol}
            </span>
          )}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          {/* Token selector button */}
          <button
            onClick={() => setTokenPickerFor('from')}
            style={{
              display: 'flex', alignItems: 'center', gap: 8,
              padding: '8px 12px', borderRadius: 20,
              background: 'var(--r-neutral-bg-2, #f2f4f7)',
              border: 'none', cursor: 'pointer',
              flexShrink: 0,
            }}
          >
            <TokenIcon token={fromToken} size={24} />
            <span style={{ fontWeight: 600, fontSize: 15, color: 'var(--r-neutral-title-1)' }}>
              {fromToken ? fromToken.symbol : 'Select'}
            </span>
            <span style={{ fontSize: 12, color: 'var(--r-neutral-foot)' }}>&darr;</span>
          </button>

          {/* Amount input */}
          <div style={{ flex: 1, position: 'relative' }}>
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
                outline: 'none',
                boxSizing: 'border-box',
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

      {/* Swap direction button */}
      <div style={{ display: 'flex', justifyContent: 'center', margin: '-8px 0', position: 'relative', zIndex: 2 }}>
        <button
          onClick={handleSwapDirection}
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

      {/* TO token input */}
      <div style={tokenInputCardStyle}>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 10 }}>
          <span style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)' }}>To</span>
          {toToken && (
            <span style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)' }}>
              Balance: {truncateAmount(toToken.amount, 4)} {toToken.symbol}
            </span>
          )}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <button
            onClick={() => setTokenPickerFor('to')}
            style={{
              display: 'flex', alignItems: 'center', gap: 8,
              padding: '8px 12px', borderRadius: 20,
              background: 'var(--r-neutral-bg-2, #f2f4f7)',
              border: 'none', cursor: 'pointer',
              flexShrink: 0,
            }}
          >
            <TokenIcon token={toToken} size={24} />
            <span style={{ fontWeight: 600, fontSize: 15, color: 'var(--r-neutral-title-1)' }}>
              {toToken ? toToken.symbol : 'Select'}
            </span>
            <span style={{ fontSize: 12, color: 'var(--r-neutral-foot)' }}>&darr;</span>
          </button>

          <input
            type="text"
            placeholder="0.0"
            value={toAmount}
            readOnly
            style={{
              flex: 1, width: '100%', border: 'none', background: 'transparent',
              textAlign: 'right', fontSize: 22, fontWeight: 600,
              color: toAmount ? 'var(--r-green-default, #27c193)' : 'var(--r-neutral-foot)',
              outline: 'none',
              boxSizing: 'border-box',
            }}
          />
        </div>
        <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 8 }}>
          <span style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)' }}>
            {toUsd && `~${toUsd}`}
          </span>
        </div>
      </div>

      {/* Slippage settings */}
      <div style={{ ...cardStyle, padding: '14px 20px', marginTop: 12 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span style={{ fontSize: 13, fontWeight: 500, color: 'var(--r-neutral-body, #3e495e)' }}>
            Slippage Tolerance
          </span>
          <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--r-neutral-title-1)' }}>
            {slippage}%
          </span>
        </div>
        <div style={{ display: 'flex', gap: 6, marginTop: 10 }}>
          {SLIPPAGE_PRESETS.map((val) => (
            <button
              key={val}
              onClick={() => {
                setSlippage(val);
                setShowCustomSlippage(false);
              }}
              style={{
                flex: 1, padding: '6px 0', borderRadius: 8,
                border: !showCustomSlippage && slippage === val
                  ? '1.5px solid var(--r-blue-default, #4c65ff)'
                  : '1px solid var(--r-neutral-line, #e0e5ec)',
                background: !showCustomSlippage && slippage === val
                  ? 'var(--r-blue-light-1, #edf0ff)'
                  : 'transparent',
                color: !showCustomSlippage && slippage === val
                  ? 'var(--r-blue-default, #4c65ff)'
                  : 'var(--r-neutral-body)',
                fontSize: 13, fontWeight: 600,
                cursor: 'pointer',
              }}
            >
              {val}%
            </button>
          ))}
          <button
            onClick={() => setShowCustomSlippage(true)}
            style={{
              flex: 1, padding: '6px 0', borderRadius: 8,
              border: showCustomSlippage
                ? '1.5px solid var(--r-blue-default, #4c65ff)'
                : '1px solid var(--r-neutral-line, #e0e5ec)',
              background: showCustomSlippage
                ? 'var(--r-blue-light-1, #edf0ff)'
                : 'transparent',
              color: showCustomSlippage
                ? 'var(--r-blue-default, #4c65ff)'
                : 'var(--r-neutral-body)',
              fontSize: 13, fontWeight: 600,
              cursor: 'pointer',
            }}
          >
            Custom
          </button>
        </div>
        {showCustomSlippage && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 8 }}>
            <input
              type="text"
              placeholder="0.5"
              value={customSlippage}
              onChange={(e) => {
                const val = e.target.value;
                if (/^\d*\.?\d*$/.test(val)) {
                  setCustomSlippage(val);
                  const num = parseFloat(val);
                  if (num > 0 && num <= 50) {
                    setSlippage(num);
                  }
                }
              }}
              style={{
                flex: 1, padding: '6px 12px', borderRadius: 8,
                border: '1px solid var(--r-neutral-line, #e0e5ec)',
                fontSize: 14, outline: 'none',
                background: 'var(--r-neutral-card-1, #fff)',
                boxSizing: 'border-box',
              }}
            />
            <span style={{ fontSize: 14, color: 'var(--r-neutral-body)' }}>%</span>
          </div>
        )}
      </div>

      {/* Quote list */}
      {(quotesLoading || quotes.length > 0) && (
        <div style={{ ...cardStyle, padding: '14px 20px', marginTop: 12 }}>
          <button
            onClick={() => setShowQuoteList(!showQuoteList)}
            style={{
              display: 'flex', justifyContent: 'space-between', alignItems: 'center',
              width: '100%', background: 'transparent', border: 'none',
              cursor: 'pointer', padding: 0,
            }}
          >
            <span style={{ fontSize: 13, fontWeight: 500, color: 'var(--r-neutral-body, #3e495e)' }}>
              {quotesLoading
                ? 'Fetching quotes...'
                : `${quotes.length} quote${quotes.length !== 1 ? 's' : ''} available`}
            </span>
            <span style={{
              fontSize: 14, color: 'var(--r-neutral-foot)',
              transform: showQuoteList ? 'rotate(90deg)' : 'rotate(0deg)',
              transition: 'transform 200ms',
            }}>
              &rsaquo;
            </span>
          </button>

          {quotesLoading && (
            <div style={{ textAlign: 'center', padding: '12px 0' }}>
              <div style={{
                width: 20, height: 20, borderRadius: '50%',
                border: '2px solid var(--r-blue-default, #4c65ff)',
                borderTopColor: 'transparent',
                animation: 'spin 0.8s linear infinite',
                margin: '0 auto',
              }} />
              <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
            </div>
          )}

          {showQuoteList && !quotesLoading && quotes.map((quote, i) => {
            const isBest = i === 0;
            const isSelected = selectedQuote?.dex_id === quote.dex_id;
            return (
              <button
                key={quote.dex_id}
                onClick={() => setSelectedQuote(quote)}
                style={{
                  display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                  width: '100%', padding: '10px 0',
                  background: 'transparent',
                  border: 'none',
                  borderTop: '1px solid var(--r-neutral-line, #e0e5ec)',
                  cursor: 'pointer',
                  textAlign: 'left',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  {quote.dex_logo ? (
                    <img src={quote.dex_logo} alt={quote.dex_name} style={{ width: 28, height: 28, borderRadius: 6 }} />
                  ) : (
                    <div style={{
                      width: 28, height: 28, borderRadius: 6,
                      background: 'var(--r-blue-light-1, #edf0ff)',
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      fontSize: 12, fontWeight: 700, color: 'var(--r-blue-default)',
                    }}>
                      {quote.dex_name?.[0] ?? 'D'}
                    </div>
                  )}
                  <div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                      <span style={{
                        fontWeight: 600, fontSize: 13,
                        color: isSelected ? 'var(--r-blue-default, #4c65ff)' : 'var(--r-neutral-title-1)',
                      }}>
                        {quote.dex_name}
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
                    {quote.gas_fee_usd != null && (
                      <span style={{ fontSize: 11, color: 'var(--r-neutral-foot)' }}>
                        Gas: ~${quote.gas_fee_usd.toFixed(2)}
                      </span>
                    )}
                  </div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div style={{
                    fontWeight: 600, fontSize: 14,
                    color: isSelected ? 'var(--r-blue-default, #4c65ff)' : 'var(--r-neutral-title-1)',
                  }}>
                    {truncateAmount(Number(quote.to_token_amount))} {quote.to_token.symbol}
                  </div>
                  {quote.price_impact != null && (
                    <div style={{
                      fontSize: 11,
                      color: quote.price_impact > 5
                        ? 'var(--r-red-default, #ec5151)'
                        : quote.price_impact > 1
                          ? 'var(--r-orange-default, #ffb020)'
                          : 'var(--r-neutral-foot)',
                    }}>
                      Impact: {quote.price_impact.toFixed(2)}%
                    </div>
                  )}
                </div>
              </button>
            );
          })}
        </div>
      )}

      {/* Quote details */}
      {selectedQuote && (
        <div style={{
          ...cardStyle,
          padding: '14px 20px', marginTop: 12,
          background: 'var(--r-neutral-bg-2, #f2f4f7)',
          boxShadow: 'none',
        }}>
          {[
            ...(rate != null
              ? [{ label: 'Rate', value: `1 ${selectedQuote.from_token.symbol} = ${rate.toFixed(6)} ${selectedQuote.to_token.symbol}` }]
              : []),
            ...(selectedQuote.price_impact != null
              ? [{
                  label: 'Price Impact',
                  value: `${selectedQuote.price_impact.toFixed(2)}%`,
                  color: selectedQuote.price_impact > 5
                    ? 'var(--r-red-default, #ec5151)'
                    : selectedQuote.price_impact > 1
                      ? 'var(--r-orange-default, #ffb020)'
                      : undefined,
                }]
              : []),
            ...(minReceived != null
              ? [{ label: 'Minimum Received', value: `${truncateAmount(minReceived)} ${selectedQuote.to_token.symbol}` }]
              : []),
            ...(selectedQuote.gas_fee_usd != null
              ? [{ label: 'Est. Gas Fee', value: `$${selectedQuote.gas_fee_usd.toFixed(2)}` }]
              : []),
          ].map((row) => (
            <div key={row.label} style={{
              display: 'flex', justifyContent: 'space-between', padding: '3px 0',
            }}>
              <span style={{ fontSize: 13, color: 'var(--r-neutral-foot, #6a7587)' }}>{row.label}</span>
              <span style={{
                fontSize: 13, fontWeight: 500,
                color: ('color' in row && row.color) || 'var(--r-neutral-title-1, #192945)',
              }}>
                {row.value}
              </span>
            </div>
          ))}
        </div>
      )}

      {/* Swap button */}
      <button
        onClick={handleSwap}
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
      {renderTokenPicker()}
      {renderConfirmModal()}
    </div>
  );
};

export default SwapForm;
