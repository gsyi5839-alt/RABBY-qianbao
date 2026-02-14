import React, { useState } from 'react';
import clsx from 'clsx';
import type { NFTCollection } from '@rabby/shared';
import { formatUsdValue } from '../../../utils';
import { NFTItemCard } from './NFTItemCard';

interface NFTCollectionCardProps {
  collection: NFTCollection;
  starred: boolean;
  onToggleStar: (id: string) => void;
  onNFTClick: (nft: NFTCollection['nft_list'][number]) => void;
}

export const NFTCollectionCard: React.FC<NFTCollectionCardProps> = ({
  collection,
  starred,
  onToggleStar,
  onNFTClick,
}) => {
  const [expanded, setExpanded] = useState(false);

  return (
    <div className="bg-[var(--r-neutral-card-1)] rounded-xl overflow-hidden">
      {/* Collection header */}
      <button
        className="w-full flex items-center gap-3 p-3 min-h-[56px]"
        onClick={() => setExpanded(!expanded)}
      >
        {/* Logo */}
        {collection.logo_url ? (
          <img
            src={collection.logo_url}
            alt={collection.name}
            className="w-10 h-10 rounded-lg object-cover flex-shrink-0"
          />
        ) : (
          <div className="w-10 h-10 rounded-lg bg-[var(--r-neutral-line)] flex items-center justify-center flex-shrink-0">
            <span className="text-xs font-bold text-[var(--r-neutral-foot)]">
              {collection.name.charAt(0)}
            </span>
          </div>
        )}

        {/* Name + floor price */}
        <div className="flex-1 min-w-0 text-left">
          <div className="flex items-center gap-2">
            <span className="text-sm font-medium text-[var(--r-neutral-title-1)] truncate">
              {collection.name}
            </span>
            <span className="flex-shrink-0 text-xs text-[var(--r-neutral-foot)] bg-[var(--r-neutral-bg-2)] rounded px-1.5 py-0.5">
              {collection.amount}
            </span>
          </div>
          {collection.floor_price != null && (
            <span className="text-xs text-[var(--r-neutral-foot)]">
              Floor: {formatUsdValue(collection.floor_price)}
            </span>
          )}
        </div>

        {/* Star button */}
        <button
          className="flex-shrink-0 p-1 min-w-[44px] min-h-[44px] flex items-center justify-center"
          onClick={(e) => {
            e.stopPropagation();
            onToggleStar(collection.id);
          }}
        >
          <StarIcon filled={starred} />
        </button>

        {/* Expand chevron */}
        <div className="flex-shrink-0">
          <svg
            width="16"
            height="16"
            viewBox="0 0 16 16"
            fill="none"
            className={clsx(
              'transition-transform text-[var(--r-neutral-foot)]',
              expanded && 'rotate-180'
            )}
          >
            <path
              d="M4 6l4 4 4-4"
              stroke="currentColor"
              strokeWidth="1.5"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </div>
      </button>

      {/* Expanded NFT grid */}
      {expanded && (
        <div className="px-3 pb-3 grid grid-cols-3 gap-2">
          {collection.nft_list.map((nft) => (
            <NFTItemCard key={nft.id} nft={nft} onClick={() => onNFTClick(nft)} />
          ))}
        </div>
      )}
    </div>
  );
};

// ---------------------------------------------------------------------------
// Star Icon
// ---------------------------------------------------------------------------
const StarIcon: React.FC<{ filled: boolean }> = ({ filled }) => (
  <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
    <path
      d="M9 2l2.12 4.3 4.74.69-3.43 3.34.81 4.72L9 12.77l-4.24 2.28.81-4.72L2.14 6.99l4.74-.69L9 2z"
      stroke={filled ? 'var(--rabby-brand)' : 'var(--r-neutral-foot)'}
      strokeWidth="1.2"
      strokeLinejoin="round"
      fill={filled ? 'var(--rabby-brand)' : 'none'}
    />
  </svg>
);
