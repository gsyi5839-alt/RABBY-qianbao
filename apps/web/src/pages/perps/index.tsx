import { useState } from 'react';
import { useWallet } from '../../contexts/WalletContext';

interface Market {
  pair: string;
  price: string;
  change24h: number;
}

const MARKETS: Market[] = [
  { pair: 'BTC/USDC', price: '67,245.30', change24h: 2.34 },
  { pair: 'ETH/USDC', price: '3,521.18', change24h: -1.12 },
  { pair: 'SOL/USDC', price: '178.42', change24h: 5.67 },
  { pair: 'ARB/USDC', price: '1.23', change24h: -0.45 },
];

const LEVERAGE_OPTIONS = [2, 5, 10, 20, 50];

export default function PerpsPage() {
  const { connected } = useWallet();
  const [selectedMarket, setSelectedMarket] = useState(MARKETS[0]);
  const [direction, setDirection] = useState<'long' | 'short'>('long');
  const [leverage, setLeverage] = useState(10);
  const [positionSize, setPositionSize] = useState('');

  return (
    <div style={{ padding: 24, maxWidth: 600, margin: '0 auto' }}>
      <div style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        marginBottom: 24,
      }}>
        <h2 style={{
          fontSize: 24,
          fontWeight: 600,
          color: 'var(--r-neutral-title-1, #192945)',
          margin: 0,
        }}>
          Perpetual Trading
        </h2>
        <span style={{
          fontSize: 12,
          fontWeight: 500,
          color: 'var(--r-blue-default, #4c65ff)',
          padding: '4px 12px',
          borderRadius: 6,
          background: 'rgba(76,101,255,0.1)',
        }}>
          Coming Soon
        </span>
      </div>

      {/* Market Selector */}
      <div style={{
        background: 'var(--r-neutral-card-1, #fff)',
        borderRadius: 16,
        padding: 20,
        marginBottom: 16,
      }}>
        <div style={{
          fontSize: 14,
          fontWeight: 500,
          color: 'var(--r-neutral-title-1, #192945)',
          marginBottom: 14,
        }}>
          Select Market
        </div>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          {MARKETS.map((m) => {
            const isActive = m.pair === selectedMarket.pair;
            return (
              <button
                key={m.pair}
                onClick={() => setSelectedMarket(m)}
                style={{
                  padding: '10px 16px',
                  borderRadius: 10,
                  border: isActive
                    ? '2px solid var(--r-blue-default, #4c65ff)'
                    : '2px solid var(--r-neutral-line, #e5e9ef)',
                  background: isActive
                    ? 'rgba(76,101,255,0.06)'
                    : 'var(--r-neutral-card-2, #f2f4f7)',
                  cursor: 'pointer',
                  transition: 'border-color 0.15s, background 0.15s',
                }}
              >
                <div style={{
                  fontSize: 13,
                  fontWeight: 600,
                  color: isActive
                    ? 'var(--r-blue-default, #4c65ff)'
                    : 'var(--r-neutral-title-1, #192945)',
                }}>
                  {m.pair}
                </div>
                <div style={{
                  fontSize: 11,
                  marginTop: 2,
                  color: m.change24h >= 0
                    ? 'var(--r-green-default, #27c193)'
                    : 'var(--r-red-default, #ec5151)',
                }}>
                  ${m.price} ({m.change24h >= 0 ? '+' : ''}{m.change24h}%)
                </div>
              </button>
            );
          })}
        </div>
      </div>

      {/* Selected Market Info */}
      <div style={{
        background: 'var(--r-neutral-card-1, #fff)',
        borderRadius: 16,
        padding: 20,
        marginBottom: 16,
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
      }}>
        <div>
          <div style={{
            fontSize: 20,
            fontWeight: 700,
            color: 'var(--r-neutral-title-1, #192945)',
          }}>
            {selectedMarket.pair}
          </div>
          <div style={{
            fontSize: 13,
            color: 'var(--r-neutral-foot, #6a7587)',
            marginTop: 4,
          }}>
            Perpetual Contract
          </div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div style={{
            fontSize: 20,
            fontWeight: 700,
            color: 'var(--r-neutral-title-1, #192945)',
          }}>
            ${selectedMarket.price}
          </div>
          <div style={{
            fontSize: 13,
            fontWeight: 500,
            color: selectedMarket.change24h >= 0
              ? 'var(--r-green-default, #27c193)'
              : 'var(--r-red-default, #ec5151)',
            marginTop: 4,
          }}>
            {selectedMarket.change24h >= 0 ? '+' : ''}{selectedMarket.change24h}%
          </div>
        </div>
      </div>

      {/* Long / Short Toggle */}
      <div style={{
        background: 'var(--r-neutral-card-1, #fff)',
        borderRadius: 16,
        padding: 20,
        marginBottom: 16,
      }}>
        <div style={{
          display: 'flex',
          borderRadius: 10,
          overflow: 'hidden',
          border: '1px solid var(--r-neutral-line, #e5e9ef)',
          marginBottom: 20,
        }}>
          <button
            onClick={() => setDirection('long')}
            style={{
              flex: 1,
              padding: '14px 0',
              border: 'none',
              fontSize: 15,
              fontWeight: 600,
              cursor: 'pointer',
              color: direction === 'long' ? '#fff' : 'var(--r-neutral-foot, #6a7587)',
              background: direction === 'long'
                ? 'var(--r-green-default, #27c193)'
                : 'transparent',
              transition: 'background 0.2s, color 0.2s',
            }}
          >
            Long
          </button>
          <button
            onClick={() => setDirection('short')}
            style={{
              flex: 1,
              padding: '14px 0',
              border: 'none',
              fontSize: 15,
              fontWeight: 600,
              cursor: 'pointer',
              color: direction === 'short' ? '#fff' : 'var(--r-neutral-foot, #6a7587)',
              background: direction === 'short'
                ? 'var(--r-red-default, #ec5151)'
                : 'transparent',
              transition: 'background 0.2s, color 0.2s',
            }}
          >
            Short
          </button>
        </div>

        {/* Leverage Slider */}
        <div style={{ marginBottom: 20 }}>
          <div style={{
            display: 'flex',
            justifyContent: 'space-between',
            marginBottom: 10,
          }}>
            <span style={{
              fontSize: 14,
              fontWeight: 500,
              color: 'var(--r-neutral-title-1, #192945)',
            }}>
              Leverage
            </span>
            <span style={{
              fontSize: 14,
              fontWeight: 700,
              color: 'var(--r-blue-default, #4c65ff)',
            }}>
              {leverage}x
            </span>
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            {LEVERAGE_OPTIONS.map((lev) => (
              <button
                key={lev}
                onClick={() => setLeverage(lev)}
                style={{
                  flex: 1,
                  padding: '8px 0',
                  borderRadius: 8,
                  border: leverage === lev
                    ? '2px solid var(--r-blue-default, #4c65ff)'
                    : '1px solid var(--r-neutral-line, #e5e9ef)',
                  background: leverage === lev
                    ? 'rgba(76,101,255,0.06)'
                    : 'var(--r-neutral-card-2, #f2f4f7)',
                  color: leverage === lev
                    ? 'var(--r-blue-default, #4c65ff)'
                    : 'var(--r-neutral-title-1, #192945)',
                  fontSize: 13,
                  fontWeight: 600,
                  cursor: 'pointer',
                  transition: 'border-color 0.15s',
                }}
              >
                {lev}x
              </button>
            ))}
          </div>
        </div>

        {/* Position Size */}
        <div>
          <div style={{
            fontSize: 14,
            fontWeight: 500,
            color: 'var(--r-neutral-title-1, #192945)',
            marginBottom: 10,
          }}>
            Position Size (USDC)
          </div>
          <input
            type="text"
            placeholder="0.00"
            value={positionSize}
            onChange={(e) => {
              const val = e.target.value;
              if (/^[0-9]*\.?[0-9]*$/.test(val)) setPositionSize(val);
            }}
            style={{
              width: '100%',
              padding: '14px 16px',
              borderRadius: 8,
              border: '1px solid var(--r-neutral-line, #e5e9ef)',
              outline: 'none',
              fontSize: 18,
              fontWeight: 600,
              color: 'var(--r-neutral-title-1, #192945)',
              background: 'var(--r-neutral-card-2, #f2f4f7)',
              boxSizing: 'border-box',
            }}
          />
          {positionSize && (
            <div style={{
              fontSize: 12,
              color: 'var(--r-neutral-foot, #6a7587)',
              marginTop: 8,
            }}>
              Effective position: ${(parseFloat(positionSize || '0') * leverage).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })} USDC
            </div>
          )}
        </div>
      </div>

      {/* Action Button */}
      <button
        disabled={!connected}
        style={{
          width: '100%',
          padding: '16px 0',
          borderRadius: 8,
          border: 'none',
          fontSize: 16,
          fontWeight: 600,
          cursor: 'not-allowed',
          color: '#fff',
          background: direction === 'long'
            ? 'var(--r-green-default, #27c193)'
            : 'var(--r-red-default, #ec5151)',
          opacity: 0.5,
        }}
      >
        {!connected
          ? 'Connect Wallet'
          : `${direction === 'long' ? 'Long' : 'Short'} ${selectedMarket.pair} -- Coming Soon`}
      </button>

      {/* Info Notice */}
      <div style={{
        marginTop: 16,
        padding: 16,
        borderRadius: 12,
        background: 'rgba(76,101,255,0.06)',
        textAlign: 'center',
      }}>
        <div style={{
          fontSize: 13,
          color: 'var(--r-neutral-foot, #6a7587)',
          lineHeight: 1.6,
        }}>
          Perpetual trading is under development. This interface shows a preview of the upcoming feature.
          Stay tuned for updates.
        </div>
      </div>
    </div>
  );
}
