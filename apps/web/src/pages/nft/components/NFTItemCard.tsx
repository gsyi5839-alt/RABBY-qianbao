import React from 'react';
import clsx from 'clsx';
import type { NFTItem } from '@rabby/shared';

interface NFTItemCardProps {
  nft: NFTItem;
  onClick: () => void;
  className?: string;
}

export const NFTItemCard: React.FC<NFTItemCardProps> = ({
  nft,
  onClick,
  className,
}) => {
  return (
    <button
      className={clsx(
        'relative flex flex-col rounded-lg overflow-hidden',
        'bg-[var(--r-neutral-bg-2)] min-h-[44px]',
        'active:opacity-80 transition-opacity',
        className
      )}
      onClick={onClick}
    >
      {/* Image */}
      <div className="aspect-square w-full bg-[var(--r-neutral-line)] overflow-hidden">
        {nft.thumbnail_url || nft.content ? (
          <img
            src={nft.thumbnail_url || nft.content}
            alt={nft.name}
            className="w-full h-full object-cover"
            loading="lazy"
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center">
            <NFTPlaceholderIcon />
          </div>
        )}
      </div>

      {/* Name */}
      <div className="px-1.5 py-1.5">
        <span className="text-xs text-[var(--r-neutral-title-1)] truncate block">
          {nft.name}
        </span>
      </div>

      {/* Amount badge (for ERC-1155) */}
      {nft.amount > 1 && (
        <div className="absolute top-1 right-1 bg-black/60 text-white text-[10px] px-1.5 py-0.5 rounded">
          x{nft.amount}
        </div>
      )}
    </button>
  );
};

const NFTPlaceholderIcon = () => (
  <svg
    width="32"
    height="32"
    viewBox="0 0 32 32"
    fill="none"
    className="text-[var(--r-neutral-foot)]"
  >
    <rect
      x="4"
      y="8"
      width="24"
      height="18"
      rx="2"
      stroke="currentColor"
      strokeWidth="1.5"
    />
    <path
      d="M4 20l7-5 4 3 6-7 7 5"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
    <circle cx="11" cy="14" r="2" stroke="currentColor" strokeWidth="1.5" />
  </svg>
);
