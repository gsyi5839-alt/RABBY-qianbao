import React, { useState } from 'react';
import { useWallet } from '../../contexts/WalletContext';
import type { NFTCollection, NFTItem } from '@rabby/shared';

const MOCK_COLLECTIONS: NFTCollection[] = [
  {
    id: 'bayc',
    chain: 'eth',
    name: 'Bored Ape Yacht Club',
    symbol: 'BAYC',
    logo_url: '',
    is_core: true,
    floor_price: 28.5,
    amount: 2,
    nft_list: [
      { id: 'bayc-42', contract_id: '0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D', inner_id: '42', chain: 'eth', name: 'BAYC #42', content_type: 'image', content: '', amount: 1 },
      { id: 'bayc-108', contract_id: '0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D', inner_id: '108', chain: 'eth', name: 'BAYC #108', content_type: 'image', content: '', amount: 1 },
    ],
  },
  {
    id: 'azuki',
    chain: 'eth',
    name: 'Azuki',
    symbol: 'AZUKI',
    logo_url: '',
    is_core: true,
    floor_price: 6.2,
    amount: 1,
    nft_list: [
      { id: 'azuki-123', contract_id: '0xED5AF388653567Af2F388E6224dC7C4b3241C544', inner_id: '123', chain: 'eth', name: 'Azuki #123', content_type: 'image', content: '', amount: 1 },
    ],
  },
];

export default function NFTPage() {
  const { connected } = useWallet();
  const [expandedCollection, setExpandedCollection] = useState<string | null>(null);
  const [viewMode, setViewMode] = useState<'grid' | 'list'>('grid');
  const collections = MOCK_COLLECTIONS;

  if (!connected) {
    return (
      <div style={{ textAlign: 'center', padding: 60 }}>
        <div style={{ fontSize: 48, marginBottom: 16 }}>{'\u{1F5BC}'}</div>
        <h2 style={{ color: 'var(--r-neutral-title-1)', margin: '0 0 8px' }}>NFT Gallery</h2>
        <p style={{ color: 'var(--r-neutral-foot)' }}>Connect wallet to view your NFTs</p>
      </div>
    );
  }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, margin: 0, color: 'var(--r-neutral-title-1, #192945)' }}>
          NFT Gallery
        </h2>
        <div style={{ display: 'flex', gap: 4 }}>
          {(['grid', 'list'] as const).map((mode) => (
            <button
              key={mode}
              onClick={() => setViewMode(mode)}
              style={{
                padding: '6px 10px', borderRadius: 6, border: 'none',
                background: viewMode === mode ? 'var(--r-blue-default, #4c65ff)' : 'var(--r-neutral-card-1, #fff)',
                color: viewMode === mode ? '#fff' : 'var(--r-neutral-body)',
                cursor: 'pointer', fontSize: 14,
              }}
            >
              {mode === 'grid' ? '\u25A6' : '\u2630'}
            </button>
          ))}
        </div>
      </div>

      {collections.length === 0 ? (
        <div style={{ textAlign: 'center', padding: 40, color: 'var(--r-neutral-foot)' }}>
          No NFTs found
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          {collections.map((collection) => {
            const isExpanded = expandedCollection === collection.id;
            return (
              <div key={collection.id} style={{
                background: 'var(--r-neutral-card-1, #fff)',
                borderRadius: 16,
                overflow: 'hidden',
                boxShadow: 'var(--rabby-shadow-sm, 0 2px 4px rgba(0,0,0,0.04))',
              }}>
                {/* Collection Header */}
                <button
                  onClick={() => setExpandedCollection(isExpanded ? null : collection.id)}
                  style={{
                    display: 'flex', alignItems: 'center', gap: 14,
                    width: '100%', padding: '16px 20px',
                    background: 'transparent', border: 'none',
                    cursor: 'pointer', textAlign: 'left' as const,
                  }}
                >
                  <div style={{
                    width: 48, height: 48, borderRadius: 10,
                    background: 'linear-gradient(135deg, var(--r-blue-light-1, #edf0ff), var(--r-blue-light-2, #dbdfff))',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: 20, fontWeight: 700, color: 'var(--r-blue-default)',
                  }}>
                    {collection.name[0]}
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontWeight: 600, fontSize: 15, color: 'var(--r-neutral-title-1, #192945)' }}>
                      {collection.name}
                    </div>
                    <div style={{ fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)', marginTop: 2 }}>
                      {collection.amount} item{collection.amount !== 1 ? 's' : ''}
                      {collection.floor_price ? ` \u00B7 Floor: ${collection.floor_price} ETH` : ''}
                    </div>
                  </div>
                  <span style={{
                    color: 'var(--r-neutral-foot)',
                    transform: isExpanded ? 'rotate(90deg)' : 'rotate(0deg)',
                    transition: 'transform 200ms',
                    fontSize: 16,
                  }}>
                    &rsaquo;
                  </span>
                </button>

                {/* Expanded NFT grid */}
                {isExpanded && (
                  <div style={{
                    padding: '0 20px 20px',
                    display: 'grid',
                    gridTemplateColumns: viewMode === 'grid' ? 'repeat(auto-fill, minmax(140px, 1fr))' : '1fr',
                    gap: 12,
                  }}>
                    {collection.nft_list.map((nft) => (
                      <div key={nft.id} style={{
                        borderRadius: 12,
                        overflow: 'hidden',
                        background: 'var(--r-neutral-bg-2, #f2f4f7)',
                        border: '1px solid var(--r-neutral-line, #e0e5ec)',
                      }}>
                        <div style={{
                          aspectRatio: viewMode === 'grid' ? '1' : 'auto',
                          height: viewMode === 'grid' ? undefined : 60,
                          background: `linear-gradient(135deg, hsl(${(nft.inner_id.charCodeAt(0) * 37) % 360}, 60%, 75%), hsl(${(nft.inner_id.charCodeAt(0) * 73) % 360}, 60%, 65%))`,
                          display: 'flex', alignItems: 'center', justifyContent: 'center',
                          color: '#fff', fontSize: viewMode === 'grid' ? 24 : 16, fontWeight: 700,
                        }}>
                          #{nft.inner_id}
                        </div>
                        <div style={{ padding: viewMode === 'grid' ? '10px 12px' : '8px 12px' }}>
                          <div style={{
                            fontWeight: 600, fontSize: 13,
                            color: 'var(--r-neutral-title-1, #192945)',
                            marginBottom: 4,
                          }}>
                            {nft.name}
                          </div>
                          <button style={{
                            padding: '4px 10px', borderRadius: 6,
                            background: 'var(--r-blue-light-1, #edf0ff)',
                            color: 'var(--r-blue-default, #4c65ff)',
                            border: 'none', fontSize: 11, fontWeight: 600,
                            cursor: 'pointer',
                          }}>
                            Send
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
