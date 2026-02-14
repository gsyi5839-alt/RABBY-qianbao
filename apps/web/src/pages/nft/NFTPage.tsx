import React, { useState } from 'react';
import clsx from 'clsx';
import type { NFTItem } from '@rabby/shared';
import { PageHeader } from '../../components/layout';
import { Input, Loading, Empty } from '../../components/ui';
import { useChain } from '../../hooks';
import { useNFTList } from './hooks/useNFTList';
import { NFTCollectionCard } from './components/NFTCollectionCard';
import { NFTItemCard } from './components/NFTItemCard';
import { NFTDetailPopup } from './components/NFTDetailPopup';

const NFTPage: React.FC = () => {
  const {
    filteredCollections,
    loading,
    searchKeyword,
    setSearchKeyword,
    chainFilter,
    setChainFilter,
    toggleStar,
    isStar,
    viewMode,
    setViewMode,
  } = useNFTList();

  const { mainnetList } = useChain();
  const [detailNFT, setDetailNFT] = useState<NFTItem | null>(null);

  const chainOptions = [
    { value: 'all', label: 'All Chains' },
    ...mainnetList.slice(0, 10).map((c) => ({
      value: c.serverId,
      label: c.name,
    })),
  ];

  return (
    <div className="min-h-screen bg-[var(--r-neutral-bg-1)] flex flex-col">
      <PageHeader title="NFT Gallery" />

      {/* Toolbar */}
      <div className="px-4 flex flex-col gap-3 pb-3">
        {/* Search */}
        <Input
          placeholder="Search NFTs..."
          value={searchKeyword}
          onChange={(e) => setSearchKeyword(e.target.value)}
          prefix={<SearchIcon />}
        />

        {/* Filter row */}
        <div className="flex items-center gap-2">
          {/* Chain filter pills */}
          <div className="flex-1 flex gap-1.5 overflow-x-auto no-scrollbar">
            {chainOptions.map((opt) => (
              <button
                key={opt.value}
                className={clsx(
                  'flex-shrink-0 px-3 py-1.5 rounded-full text-xs font-medium',
                  'transition-colors min-h-[32px]',
                  chainFilter === opt.value
                    ? 'bg-[var(--rabby-brand)] text-white'
                    : 'bg-[var(--r-neutral-bg-2)] text-[var(--r-neutral-body)]'
                )}
                onClick={() => setChainFilter(opt.value)}
              >
                {opt.label}
              </button>
            ))}
          </div>

          {/* View toggle */}
          <div className="flex-shrink-0 flex bg-[var(--r-neutral-bg-2)] rounded-lg p-0.5">
            <button
              className={clsx(
                'p-1.5 rounded-md transition-colors',
                viewMode === 'collection'
                  ? 'bg-[var(--r-neutral-card-1)] shadow-sm'
                  : 'text-[var(--r-neutral-foot)]'
              )}
              onClick={() => setViewMode('collection')}
            >
              <ListIcon />
            </button>
            <button
              className={clsx(
                'p-1.5 rounded-md transition-colors',
                viewMode === 'grid'
                  ? 'bg-[var(--r-neutral-card-1)] shadow-sm'
                  : 'text-[var(--r-neutral-foot)]'
              )}
              onClick={() => setViewMode('grid')}
            >
              <GridIcon />
            </button>
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto px-4 pb-4">
        {loading ? (
          <div className="flex items-center justify-center py-20">
            <Loading />
          </div>
        ) : filteredCollections.length === 0 ? (
          <Empty description="No NFTs found" />
        ) : viewMode === 'collection' ? (
          <div className="flex flex-col gap-3">
            {filteredCollections.map((col) => (
              <NFTCollectionCard
                key={col.id}
                collection={col}
                starred={isStar(col.id)}
                onToggleStar={toggleStar}
                onNFTClick={setDetailNFT}
              />
            ))}
          </div>
        ) : (
          <div className="grid grid-cols-3 gap-2">
            {filteredCollections.flatMap((col) =>
              col.nft_list.map((nft) => (
                <NFTItemCard
                  key={nft.id}
                  nft={nft}
                  onClick={() => setDetailNFT(nft)}
                />
              ))
            )}
          </div>
        )}
      </div>

      {/* Detail popup */}
      <NFTDetailPopup
        nft={detailNFT}
        visible={!!detailNFT}
        onClose={() => setDetailNFT(null)}
      />
    </div>
  );
};

export default NFTPage;

// ---------------------------------------------------------------------------
// Inline Icons
// ---------------------------------------------------------------------------
const SearchIcon = () => (
  <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
    <circle cx="7" cy="7" r="5" stroke="currentColor" strokeWidth="1.5" />
    <path d="M11 11l3 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
  </svg>
);

const ListIcon = () => (
  <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
    <rect x="2" y="3" width="12" height="2" rx="0.5" fill="currentColor" />
    <rect x="2" y="7" width="12" height="2" rx="0.5" fill="currentColor" />
    <rect x="2" y="11" width="12" height="2" rx="0.5" fill="currentColor" />
  </svg>
);

const GridIcon = () => (
  <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
    <rect x="2" y="2" width="5" height="5" rx="1" fill="currentColor" />
    <rect x="9" y="2" width="5" height="5" rx="1" fill="currentColor" />
    <rect x="2" y="9" width="5" height="5" rx="1" fill="currentColor" />
    <rect x="9" y="9" width="5" height="5" rx="1" fill="currentColor" />
  </svg>
);
