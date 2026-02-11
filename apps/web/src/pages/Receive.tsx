import React, { useMemo } from 'react';
import { useWallet } from '../contexts/WalletContext';
import { useChainContext } from '../contexts/ChainContext';

export default function Receive() {
  const { connected, currentAccount } = useWallet();
  const { chains } = useChainContext();

  // Simple QR code as SVG data URL (placeholder - in production use qrcode library)
  const qrDataUrl = useMemo(() => {
    if (!currentAccount) return '';
    // Generate a simple visual placeholder for QR
    return '';
  }, [currentAccount]);

  if (!connected || !currentAccount) {
    return (
      <div style={{ textAlign: 'center', padding: 60 }}>
        <div style={{ fontSize: 48, marginBottom: 16 }}>↓</div>
        <h2 style={{ color: 'var(--r-neutral-title-1, #192945)', margin: '0 0 8px' }}>Receive</h2>
        <p style={{ color: 'var(--r-neutral-foot, #6a7587)' }}>Connect wallet to view your receive address</p>
      </div>
    );
  }

  const address = currentAccount.address;

  return (
    <div>
      {/* Page Header */}
      <h2 style={{
        fontSize: 20, fontWeight: 600, margin: '0 0 24px',
        color: 'var(--r-neutral-title-1, #192945)',
      }}>
        Receive
      </h2>

      {/* QR Code Card */}
      <div style={{
        background: 'var(--r-neutral-card-1, #fff)',
        borderRadius: 16,
        padding: 32,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        boxShadow: 'var(--rabby-shadow-sm, 0 2px 4px rgba(0,0,0,0.04))',
      }}>
        {/* QR Code placeholder */}
        <div style={{
          width: 200, height: 200,
          background: '#fff',
          border: '1px solid var(--r-neutral-line, #e0e5ec)',
          borderRadius: 12,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          marginBottom: 24,
          padding: 16,
        }}>
          {/* Grid pattern as QR placeholder */}
          <div style={{
            width: '100%', height: '100%',
            display: 'grid',
            gridTemplateColumns: 'repeat(8, 1fr)',
            gridTemplateRows: 'repeat(8, 1fr)',
            gap: 2,
          }}>
            {Array.from({ length: 64 }).map((_, i) => {
              // Create a deterministic pattern based on address
              const charCode = address.charCodeAt((i * 3) % address.length);
              const filled = charCode % 3 !== 0;
              return (
                <div
                  key={i}
                  style={{
                    background: filled ? 'var(--r-neutral-title-1, #192945)' : 'transparent',
                    borderRadius: 1,
                  }}
                />
              );
            })}
          </div>
        </div>

        {/* Address Display */}
        <div style={{
          background: 'var(--r-neutral-bg-2, #f2f4f7)',
          borderRadius: 12,
          padding: '16px 20px',
          width: '100%',
          maxWidth: 360,
          textAlign: 'center',
          marginBottom: 16,
        }}>
          <div style={{
            fontFamily: "'SF Mono', Menlo, monospace",
            fontSize: 13,
            lineHeight: '20px',
            color: 'var(--r-neutral-title-1, #192945)',
            wordBreak: 'break-all',
          }}>
            {address}
          </div>
        </div>

        {/* Copy Button */}
        <CopyButton text={address} />

        {/* Supported Networks */}
        <div style={{ marginTop: 24, width: '100%', maxWidth: 360 }}>
          <div style={{
            fontSize: 13, color: 'var(--r-neutral-foot, #6a7587)',
            marginBottom: 12, textAlign: 'center',
          }}>
            Supported Networks
          </div>
          <div style={{
            display: 'flex', flexWrap: 'wrap', gap: 8,
            justifyContent: 'center',
          }}>
            {(chains.length > 0 ? chains.slice(0, 8) : [
              { name: 'Ethereum', serverId: 'eth' },
              { name: 'BSC', serverId: 'bsc' },
              { name: 'Polygon', serverId: 'matic' },
              { name: 'Arbitrum', serverId: 'arb' },
              { name: 'Optimism', serverId: 'op' },
              { name: 'Avalanche', serverId: 'avax' },
            ]).map((chain: any) => (
              <span
                key={chain.serverId || chain.name}
                style={{
                  padding: '4px 12px',
                  background: 'var(--r-blue-light-1, #edf0ff)',
                  color: 'var(--r-blue-default, #4c65ff)',
                  borderRadius: 20,
                  fontSize: 12,
                  fontWeight: 500,
                }}
              >
                {chain.name}
              </span>
            ))}
          </div>
        </div>

        {/* Warning */}
        <div style={{
          marginTop: 24,
          padding: '12px 16px',
          background: 'var(--r-orange-light, #fff5e2)',
          borderRadius: 8,
          display: 'flex',
          alignItems: 'center',
          gap: 8,
          width: '100%',
          maxWidth: 360,
        }}>
          <span style={{ fontSize: 16, lineHeight: 1 }}>&#x26A0;&#xFE0F;</span>
          <span style={{ fontSize: 12, color: 'var(--r-orange-default, #ffb020)' }}>
            Only send assets on supported networks to this address
          </span>
        </div>
      </div>
    </div>
  );
}

function CopyButton({ text }: { text: string }) {
  const [copied, setCopied] = React.useState(false);

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {}
  };

  return (
    <button
      onClick={handleCopy}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 8,
        padding: '10px 24px',
        background: copied ? 'var(--r-green-default, #2abb7f)' : 'var(--r-blue-default, #4c65ff)',
        color: '#fff',
        border: 'none',
        borderRadius: 8,
        fontSize: 14,
        fontWeight: 600,
        cursor: 'pointer',
        transition: 'all 150ms ease-in-out',
      }}
    >
      {copied ? 'Copied!' : 'Copy Address'}
    </button>
  );
}
