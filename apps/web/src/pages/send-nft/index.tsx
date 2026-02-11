import { useState, useMemo } from 'react';
import { useWallet } from '../../contexts/WalletContext';

interface MockNFT {
  id: string;
  name: string;
  image: string;
  collection: string;
  tokenId: string;
  contractAddress: string;
}

const MOCK_NFTS: MockNFT[] = [
  { id: '1', name: 'Cool Cat #1234', image: '', collection: 'Cool Cats', tokenId: '1234', contractAddress: '0xabc1' },
  { id: '2', name: 'Bored Ape #5678', image: '', collection: 'BAYC', tokenId: '5678', contractAddress: '0xabc2' },
  { id: '3', name: 'Azuki #910', image: '', collection: 'Azuki', tokenId: '910', contractAddress: '0xabc3' },
  { id: '4', name: 'Doodle #333', image: '', collection: 'Doodles', tokenId: '333', contractAddress: '0xabc4' },
  { id: '5', name: 'Pudgy #777', image: '', collection: 'Pudgy Penguins', tokenId: '777', contractAddress: '0xabc5' },
  { id: '6', name: 'CloneX #2020', image: '', collection: 'CloneX', tokenId: '2020', contractAddress: '0xabc6' },
];

const ESTIMATED_GAS = '0.0042 ETH';

export default function SendNFTPage() {
  const { currentAccount, connected } = useWallet();
  const [selectedNFT, setSelectedNFT] = useState<MockNFT | null>(null);
  const [recipient, setRecipient] = useState('');
  const [sending, setSending] = useState(false);
  const [sent, setSent] = useState(false);

  const isValidAddress = useMemo(() => {
    return /^0x[a-fA-F0-9]{40}$/.test(recipient);
  }, [recipient]);

  const canSend = selectedNFT && isValidAddress && !sending;

  const handleSend = async () => {
    if (!canSend) return;
    setSending(true);
    // Simulate send
    await new Promise((r) => setTimeout(r, 2000));
    setSending(false);
    setSent(true);
    setTimeout(() => {
      setSent(false);
      setSelectedNFT(null);
      setRecipient('');
    }, 3000);
  };

  if (!connected) {
    return (
      <div style={{ padding: 24, maxWidth: 600, margin: '0 auto' }}>
        <h2 style={{
          fontSize: 24,
          fontWeight: 600,
          color: 'var(--r-neutral-title-1, #192945)',
          marginBottom: 16,
        }}>
          Send NFT
        </h2>
        <div style={{
          background: 'var(--r-neutral-card-1, #fff)',
          borderRadius: 16,
          padding: 40,
          textAlign: 'center',
        }}>
          <p style={{ color: 'var(--r-neutral-foot, #6a7587)', fontSize: 14 }}>
            Please connect your wallet to send NFTs.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div style={{ padding: 24, maxWidth: 600, margin: '0 auto' }}>
      <h2 style={{
        fontSize: 24,
        fontWeight: 600,
        color: 'var(--r-neutral-title-1, #192945)',
        marginBottom: 24,
      }}>
        Send NFT
      </h2>

      {/* NFT Selector Grid */}
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
          Select an NFT
        </div>
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(3, 1fr)',
          gap: 12,
        }}>
          {MOCK_NFTS.map((nft) => {
            const isSelected = selectedNFT?.id === nft.id;
            return (
              <div
                key={nft.id}
                onClick={() => setSelectedNFT(nft)}
                style={{
                  borderRadius: 12,
                  border: isSelected
                    ? '2px solid var(--r-blue-default, #4c65ff)'
                    : '2px solid var(--r-neutral-line, #e5e9ef)',
                  cursor: 'pointer',
                  overflow: 'hidden',
                  transition: 'border-color 0.2s, box-shadow 0.2s',
                  boxShadow: isSelected ? '0 0 0 3px rgba(76,101,255,0.15)' : 'none',
                }}
              >
                <div style={{
                  width: '100%',
                  aspectRatio: '1',
                  background: 'var(--r-neutral-card-2, #f2f4f7)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: 28,
                  color: 'var(--r-neutral-foot, #6a7587)',
                }}>
                  {nft.name.charAt(0)}
                </div>
                <div style={{ padding: '8px 10px' }}>
                  <div style={{
                    fontSize: 12,
                    fontWeight: 500,
                    color: 'var(--r-neutral-title-1, #192945)',
                    whiteSpace: 'nowrap',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                  }}>
                    {nft.name}
                  </div>
                  <div style={{
                    fontSize: 11,
                    color: 'var(--r-neutral-foot, #6a7587)',
                    marginTop: 2,
                  }}>
                    {nft.collection}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Selected NFT Preview */}
      {selectedNFT && (
        <div style={{
          background: 'var(--r-neutral-card-1, #fff)',
          borderRadius: 16,
          padding: 20,
          marginBottom: 16,
          display: 'flex',
          alignItems: 'center',
          gap: 16,
        }}>
          <div style={{
            width: 72,
            height: 72,
            borderRadius: 12,
            background: 'var(--r-neutral-card-2, #f2f4f7)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: 28,
            color: 'var(--r-neutral-foot, #6a7587)',
            flexShrink: 0,
          }}>
            {selectedNFT.name.charAt(0)}
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{
              fontSize: 16,
              fontWeight: 600,
              color: 'var(--r-neutral-title-1, #192945)',
              marginBottom: 4,
            }}>
              {selectedNFT.name}
            </div>
            <div style={{ fontSize: 13, color: 'var(--r-neutral-foot, #6a7587)' }}>
              {selectedNFT.collection}
            </div>
            <div style={{
              fontSize: 12,
              color: 'var(--r-neutral-foot, #6a7587)',
              fontFamily: 'monospace',
              marginTop: 4,
            }}>
              Token ID: {selectedNFT.tokenId}
            </div>
          </div>
        </div>
      )}

      {/* Recipient Address Input */}
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
          marginBottom: 10,
        }}>
          Recipient Address
        </div>
        <input
          type="text"
          placeholder="0x..."
          value={recipient}
          onChange={(e) => setRecipient(e.target.value)}
          style={{
            width: '100%',
            padding: '12px 16px',
            borderRadius: 8,
            border: recipient && !isValidAddress
              ? '1px solid var(--r-red-default, #ec5151)'
              : '1px solid var(--r-neutral-line, #e5e9ef)',
            outline: 'none',
            fontSize: 14,
            fontFamily: 'monospace',
            color: 'var(--r-neutral-title-1, #192945)',
            background: 'var(--r-neutral-card-2, #f2f4f7)',
            boxSizing: 'border-box',
          }}
        />
        {recipient && !isValidAddress && (
          <div style={{
            fontSize: 12,
            color: 'var(--r-red-default, #ec5151)',
            marginTop: 6,
          }}>
            Please enter a valid Ethereum address (0x followed by 40 hex characters)
          </div>
        )}
        {currentAccount && (
          <div style={{
            fontSize: 12,
            color: 'var(--r-neutral-foot, #6a7587)',
            marginTop: 8,
          }}>
            From: {currentAccount.address.slice(0, 6)}...{currentAccount.address.slice(-4)}
          </div>
        )}
      </div>

      {/* Gas Fee Display */}
      <div style={{
        background: 'var(--r-neutral-card-1, #fff)',
        borderRadius: 16,
        padding: 16,
        marginBottom: 20,
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
      }}>
        <span style={{ fontSize: 13, color: 'var(--r-neutral-foot, #6a7587)' }}>
          Estimated Gas Fee
        </span>
        <span style={{
          fontSize: 14,
          fontWeight: 500,
          color: 'var(--r-neutral-title-1, #192945)',
        }}>
          {ESTIMATED_GAS}
        </span>
      </div>

      {/* Send Button */}
      <button
        disabled={!canSend}
        onClick={handleSend}
        style={{
          width: '100%',
          padding: '16px 0',
          borderRadius: 8,
          border: 'none',
          fontSize: 16,
          fontWeight: 600,
          cursor: canSend ? 'pointer' : 'not-allowed',
          color: '#fff',
          background: canSend
            ? 'var(--r-blue-default, #4c65ff)'
            : 'var(--r-neutral-line, #e5e9ef)',
          transition: 'background 0.2s, opacity 0.2s',
          opacity: sending ? 0.7 : 1,
        }}
      >
        {sent
          ? 'NFT Sent Successfully!'
          : sending
            ? 'Sending...'
            : !selectedNFT
              ? 'Select an NFT'
              : !isValidAddress
                ? 'Enter Valid Address'
                : 'Send NFT'}
      </button>
    </div>
  );
}
