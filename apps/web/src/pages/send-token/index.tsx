import React, { useState, useMemo, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { useWallet } from '../../contexts/WalletContext';
import { useChainContext } from '../../contexts/ChainContext';
import { useTokenList } from '../../hooks/useTokenList';
import type { TokenItem } from '@rabby/shared';

type GasLevel = 'slow' | 'standard' | 'fast' | 'custom';

const GAS_PRESETS: Record<Exclude<GasLevel, 'custom'>, { label: string; multiplier: number; time: string }> = {
  slow: { label: 'Slow', multiplier: 0.8, time: '~5 min' },
  standard: { label: 'Standard', multiplier: 1, time: '~2 min' },
  fast: { label: 'Fast', multiplier: 1.3, time: '~30 sec' },
};

export default function SendToken() {
  const navigate = useNavigate();
  const { connected, currentAccount, sendTransaction } = useWallet();
  const { currentChain, chains } = useChainContext();
  const { tokens, loading: tokensLoading } = useTokenList(currentChain?.serverId);

  const [selectedToken, setSelectedToken] = useState<TokenItem | null>(null);
  const [amount, setAmount] = useState('');
  const [recipient, setRecipient] = useState('');
  const [gasLevel, setGasLevel] = useState<GasLevel>('standard');
  const [showTokenPicker, setShowTokenPicker] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [sending, setSending] = useState(false);
  const [tokenSearch, setTokenSearch] = useState('');

  const filteredTokens = useMemo(() => {
    if (!tokenSearch) return tokens;
    const q = tokenSearch.toLowerCase();
    return tokens.filter((t) => t.symbol.toLowerCase().includes(q) || t.name.toLowerCase().includes(q));
  }, [tokens, tokenSearch]);

  const usdValue = useMemo(() => {
    if (!selectedToken || !amount || isNaN(Number(amount))) return 0;
    return Number(amount) * selectedToken.price;
  }, [selectedToken, amount]);

  const estimatedGas = useMemo(() => {
    const base = 0.002; // base gas in native token
    const mul = gasLevel === 'custom' ? 1 : GAS_PRESETS[gasLevel].multiplier;
    return base * mul;
  }, [gasLevel]);

  const isValidAddress = recipient.startsWith('0x') && recipient.length === 42;
  const hasEnoughBalance = selectedToken ? Number(amount) <= selectedToken.amount : false;

  const buttonState = useMemo(() => {
    if (!selectedToken) return { disabled: true, label: 'Select Token' };
    if (!amount || Number(amount) <= 0) return { disabled: true, label: 'Enter Amount' };
    if (!hasEnoughBalance) return { disabled: true, label: 'Insufficient Balance' };
    if (!recipient) return { disabled: true, label: 'Enter Recipient' };
    if (!isValidAddress) return { disabled: true, label: 'Invalid Address' };
    return { disabled: false, label: 'Send' };
  }, [selectedToken, amount, hasEnoughBalance, recipient, isValidAddress]);

  const handleMax = useCallback(() => {
    if (selectedToken) {
      setAmount(String(selectedToken.amount));
    }
  }, [selectedToken]);

  const handleSend = useCallback(async () => {
    if (!currentAccount || !selectedToken) return;
    setSending(true);
    try {
      await sendTransaction({
        from: currentAccount.address,
        to: recipient,
        value: amount,
        chainId: currentChain?.id,
      });
      setShowConfirm(false);
      setAmount('');
      setRecipient('');
      setSelectedToken(null);
    } catch (err) {
      console.error('Send failed:', err);
    } finally {
      setSending(false);
    }
  }, [currentAccount, selectedToken, recipient, amount, currentChain, sendTransaction]);

  if (!connected) {
    return (
      <div style={{ textAlign: 'center', padding: 60 }}>
        <div style={{ fontSize: 48, marginBottom: 16 }}>↑</div>
        <h2 style={{ color: 'var(--r-neutral-title-1, #192945)', margin: '0 0 8px' }}>Send Token</h2>
        <p style={{ color: 'var(--r-neutral-foot, #6a7587)' }}>Connect wallet to send tokens</p>
      </div>
    );
  }

  return (
    <div>
      <h2 style={{ fontSize: 20, fontWeight: 600, margin: '0 0 24px', color: 'var(--r-neutral-title-1, #192945)' }}>
        Send Token
      </h2>

      {/* Token Selection */}
      <div style={{
        background: 'var(--r-neutral-card-1, #fff)', borderRadius: 16,
        padding: 20, marginBottom: 12,
        boxShadow: 'var(--rabby-shadow-sm, 0 2px 4px rgba(0,0,0,0.04))',
      }}>
        <div style={{ fontSize: 13, color: 'var(--r-neutral-foot, #6a7587)', marginBottom: 8 }}>Token</div>
        <button
          onClick={() => setShowTokenPicker(true)}
          style={{
            display: 'flex', alignItems: 'center', gap: 10, width: '100%',
            padding: '12px 16px',
            background: 'var(--r-neutral-bg-2, #f2f4f7)', border: 'none',
            borderRadius: 12, cursor: 'pointer', textAlign: 'left',
          }}
        >
          {selectedToken ? (
            <>
              <div style={{
                width: 28, height: 28, borderRadius: '50%',
                background: selectedToken.logo_url ? 'none' : 'var(--r-blue-light-1, #edf0ff)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                color: 'var(--r-blue-default)', fontSize: 12, fontWeight: 600, overflow: 'hidden',
              }}>
                {selectedToken.logo_url ? (
                  <img src={selectedToken.logo_url} style={{ width: 28, height: 28 }} alt="" />
                ) : selectedToken.symbol[0]}
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 600, color: 'var(--r-neutral-title-1, #192945)', fontSize: 15 }}>
                  {selectedToken.symbol}
                </div>
                <div style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)' }}>
                  Balance: {selectedToken.amount.toLocaleString(undefined, { maximumFractionDigits: 6 })}
                </div>
              </div>
            </>
          ) : (
            <span style={{ color: 'var(--r-neutral-foot, #6a7587)', fontSize: 14 }}>Select a token ▾</span>
          )}
        </button>

        {/* Amount Input */}
        <div style={{ marginTop: 16 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
            <span style={{ fontSize: 13, color: 'var(--r-neutral-foot, #6a7587)' }}>Amount</span>
            {selectedToken && (
              <span style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)' }}>
                Balance: {selectedToken.amount.toLocaleString(undefined, { maximumFractionDigits: 6 })} {selectedToken.symbol}
              </span>
            )}
          </div>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 8,
            background: 'var(--r-neutral-bg-2, #f2f4f7)',
            borderRadius: 12, padding: '4px 12px',
            border: amount && !hasEnoughBalance && Number(amount) > 0 ? '1px solid var(--r-red-default, #e34935)' : '1px solid transparent',
          }}>
            <input
              type="number"
              placeholder="0.0"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              style={{
                flex: 1, border: 'none', background: 'transparent', outline: 'none',
                fontSize: 20, fontWeight: 600, color: 'var(--r-neutral-title-1, #192945)',
                padding: '10px 0',
              }}
            />
            <button
              onClick={handleMax}
              style={{
                padding: '4px 10px', borderRadius: 6,
                background: 'var(--r-blue-light-1, #edf0ff)',
                color: 'var(--r-blue-default, #4c65ff)',
                border: 'none', fontSize: 12, fontWeight: 600, cursor: 'pointer',
              }}
            >
              MAX
            </button>
          </div>
          {usdValue > 0 && (
            <div style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)', marginTop: 4, paddingLeft: 4 }}>
              ≈ ${usdValue.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
            </div>
          )}
          {amount && Number(amount) > 0 && !hasEnoughBalance && (
            <div style={{ fontSize: 12, color: 'var(--r-red-default, #e34935)', marginTop: 4, paddingLeft: 4 }}>
              Insufficient balance
            </div>
          )}
        </div>
      </div>

      {/* Recipient */}
      <div style={{
        background: 'var(--r-neutral-card-1, #fff)', borderRadius: 16,
        padding: 20, marginBottom: 12,
        boxShadow: 'var(--rabby-shadow-sm, 0 2px 4px rgba(0,0,0,0.04))',
      }}>
        <div style={{ fontSize: 13, color: 'var(--r-neutral-foot, #6a7587)', marginBottom: 8 }}>Recipient</div>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 8,
          background: 'var(--r-neutral-bg-2, #f2f4f7)',
          borderRadius: 12, padding: '4px 12px',
          border: recipient && !isValidAddress ? '1px solid var(--r-red-default, #e34935)' : '1px solid transparent',
        }}>
          <input
            placeholder="0x... or ENS name"
            value={recipient}
            onChange={(e) => setRecipient(e.target.value)}
            style={{
              flex: 1, border: 'none', background: 'transparent', outline: 'none',
              fontSize: 14, color: 'var(--r-neutral-title-1, #192945)',
              padding: '12px 0',
              fontFamily: "'SF Mono', Menlo, monospace",
            }}
          />
        </div>
        {recipient && !isValidAddress && (
          <div style={{ fontSize: 12, color: 'var(--r-red-default, #e34935)', marginTop: 4, paddingLeft: 4 }}>
            Invalid address format
          </div>
        )}
      </div>

      {/* Gas Settings */}
      <div style={{
        background: 'var(--r-neutral-card-1, #fff)', borderRadius: 16,
        padding: 20, marginBottom: 20,
        boxShadow: 'var(--rabby-shadow-sm, 0 2px 4px rgba(0,0,0,0.04))',
      }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
          <span style={{ fontSize: 13, color: 'var(--r-neutral-foot, #6a7587)' }}>Gas Fee</span>
          <span style={{ fontSize: 13, color: 'var(--r-neutral-body, #3e495e)' }}>
            ≈ {estimatedGas.toFixed(4)} ETH (~${(estimatedGas * 2345).toFixed(2)})
          </span>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          {(['slow', 'standard', 'fast'] as const).map((level) => {
            const preset = GAS_PRESETS[level];
            const active = gasLevel === level;
            return (
              <button
                key={level}
                onClick={() => setGasLevel(level)}
                style={{
                  flex: 1, padding: '10px 8px',
                  borderRadius: 10,
                  border: active ? '2px solid var(--r-blue-default, #4c65ff)' : '1px solid var(--r-neutral-line, #e0e5ec)',
                  background: active ? 'var(--r-blue-light-1, #edf0ff)' : 'transparent',
                  cursor: 'pointer',
                  textAlign: 'center',
                }}
              >
                <div style={{
                  fontWeight: 600, fontSize: 13,
                  color: active ? 'var(--r-blue-default, #4c65ff)' : 'var(--r-neutral-title-1, #192945)',
                }}>
                  {preset.label}
                </div>
                <div style={{ fontSize: 11, color: 'var(--r-neutral-foot, #6a7587)', marginTop: 2 }}>
                  {preset.time}
                </div>
              </button>
            );
          })}
        </div>
      </div>

      {/* Send Button */}
      <button
        disabled={buttonState.disabled}
        onClick={() => setShowConfirm(true)}
        style={{
          width: '100%', padding: '16px 0',
          borderRadius: 12, border: 'none',
          background: buttonState.disabled ? 'var(--r-blue-disable, #a5b2ff)' : 'var(--r-blue-default, #4c65ff)',
          color: '#fff', fontSize: 16, fontWeight: 600,
          cursor: buttonState.disabled ? 'not-allowed' : 'pointer',
          transition: 'all 150ms ease-in-out',
        }}
      >
        {buttonState.label}
      </button>

      {/* Token Picker Modal */}
      {showTokenPicker && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(0,0,0,0.4)', zIndex: 200,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          padding: 24,
        }} onClick={() => setShowTokenPicker(false)}>
          <div
            style={{
              background: 'var(--r-neutral-bg-1, #fff)', borderRadius: 16,
              width: '100%', maxWidth: 400, maxHeight: '70vh',
              display: 'flex', flexDirection: 'column',
              boxShadow: 'var(--rabby-shadow-lg, 0 8px 24px rgba(0,0,0,0.12))',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--r-neutral-line, #e0e5ec)' }}>
              <h3 style={{ margin: '0 0 12px', fontSize: 16, color: 'var(--r-neutral-title-1)' }}>Select Token</h3>
              <input
                placeholder="Search token name or symbol"
                value={tokenSearch}
                onChange={(e) => setTokenSearch(e.target.value)}
                style={{
                  width: '100%', padding: '10px 14px', border: '1px solid var(--r-neutral-line, #e0e5ec)',
                  borderRadius: 8, outline: 'none', fontSize: 14, boxSizing: 'border-box',
                  background: 'var(--r-neutral-bg-2, #f2f4f7)',
                  color: 'var(--r-neutral-title-1)',
                }}
              />
            </div>
            <div style={{ flex: 1, overflow: 'auto', padding: '8px 12px' }}>
              {filteredTokens.map((token) => (
                <button
                  key={token.id}
                  onClick={() => { setSelectedToken(token); setShowTokenPicker(false); setTokenSearch(''); }}
                  style={{
                    display: 'flex', alignItems: 'center', gap: 12, width: '100%',
                    padding: '12px 8px', background: selectedToken?.id === token.id ? 'var(--r-blue-light-1, #edf0ff)' : 'transparent',
                    border: 'none', borderRadius: 10, cursor: 'pointer', textAlign: 'left',
                  }}
                >
                  <div style={{
                    width: 32, height: 32, borderRadius: '50%',
                    background: token.logo_url ? 'none' : 'var(--r-blue-light-1)',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: 13, fontWeight: 600, color: 'var(--r-blue-default)',
                    overflow: 'hidden', flexShrink: 0,
                  }}>
                    {token.logo_url ? <img src={token.logo_url} style={{ width: 32, height: 32 }} alt="" /> : token.symbol[0]}
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--r-neutral-title-1)' }}>{token.symbol}</div>
                    <div style={{ fontSize: 12, color: 'var(--r-neutral-foot)' }}>{token.name}</div>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <div style={{ fontWeight: 500, fontSize: 14, color: 'var(--r-neutral-title-1)' }}>
                      {token.amount.toLocaleString(undefined, { maximumFractionDigits: 4 })}
                    </div>
                    <div style={{ fontSize: 12, color: 'var(--r-neutral-foot)' }}>
                      ${(token.amount * token.price).toLocaleString('en-US', { maximumFractionDigits: 2 })}
                    </div>
                  </div>
                </button>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Confirm Modal */}
      {showConfirm && selectedToken && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(0,0,0,0.4)', zIndex: 200,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          padding: 24,
        }} onClick={() => !sending && setShowConfirm(false)}>
          <div
            style={{
              background: 'var(--r-neutral-bg-1, #fff)', borderRadius: 16,
              width: '100%', maxWidth: 400, padding: 24,
              boxShadow: 'var(--rabby-shadow-lg, 0 8px 24px rgba(0,0,0,0.12))',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <h3 style={{ margin: '0 0 20px', fontSize: 18, textAlign: 'center', color: 'var(--r-neutral-title-1)' }}>
              Confirm Send
            </h3>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 12, marginBottom: 20 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 14 }}>
                <span style={{ color: 'var(--r-neutral-foot)' }}>Token</span>
                <span style={{ fontWeight: 600, color: 'var(--r-neutral-title-1)' }}>{selectedToken.symbol}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 14 }}>
                <span style={{ color: 'var(--r-neutral-foot)' }}>Amount</span>
                <span style={{ fontWeight: 600, color: 'var(--r-neutral-title-1)' }}>
                  {amount} {selectedToken.symbol} (≈${usdValue.toFixed(2)})
                </span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 14 }}>
                <span style={{ color: 'var(--r-neutral-foot)' }}>To</span>
                <span style={{ fontFamily: "'SF Mono', monospace", fontSize: 12, color: 'var(--r-neutral-title-1)' }}>
                  {recipient.slice(0, 8)}...{recipient.slice(-6)}
                </span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 14 }}>
                <span style={{ color: 'var(--r-neutral-foot)' }}>Gas Fee</span>
                <span style={{ color: 'var(--r-neutral-title-1)' }}>≈ ${(estimatedGas * 2345).toFixed(2)}</span>
              </div>
            </div>

            <div style={{ display: 'flex', gap: 12 }}>
              <button
                onClick={() => setShowConfirm(false)}
                disabled={sending}
                style={{
                  flex: 1, padding: '14px 0', borderRadius: 10,
                  border: '1px solid var(--r-neutral-line, #e0e5ec)',
                  background: 'transparent', fontSize: 15, fontWeight: 600,
                  cursor: 'pointer', color: 'var(--r-neutral-body)',
                }}
              >
                Cancel
              </button>
              <button
                onClick={handleSend}
                disabled={sending}
                style={{
                  flex: 1, padding: '14px 0', borderRadius: 10,
                  border: 'none',
                  background: 'var(--r-blue-default, #4c65ff)',
                  color: '#fff', fontSize: 15, fontWeight: 600,
                  cursor: sending ? 'not-allowed' : 'pointer',
                  opacity: sending ? 0.7 : 1,
                }}
              >
                {sending ? 'Sending...' : 'Confirm Send'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
