import React from 'react';
import type { NFTItem, Chain } from '@rabby/shared';
import { ellipsisAddress } from '../../utils';

const FALLBACK_NFT =
  'data:image/svg+xml,' +
  encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" viewBox="0 0 200 200">' +
      '<rect width="200" height="200" fill="%23E0E5EC" rx="16"/>' +
      '<text x="100" y="105" text-anchor="middle" font-size="48" fill="%236A7587">NFT</text></svg>'
  );

interface NFTPreviewCardProps {
  nftItem: NFTItem;
  chainInfo: Chain | null;
  amount: number;
  isERC1155: boolean;
  onAmountChange: (amount: number) => void;
}

export const NFTPreviewCard: React.FC<NFTPreviewCardProps> = ({
  nftItem,
  chainInfo,
  amount,
  isERC1155,
  onAmountChange,
}) => {
  return (
    <div className="bg-[var(--r-neutral-card-1)] rounded-2xl p-4 mb-4">
      <div className="flex gap-4">
        <div className="w-20 h-20 rounded-xl overflow-hidden flex-shrink-0 bg-[var(--r-neutral-bg-2)]">
          {nftItem.content ? (
            <img
              src={nftItem.thumbnail_url || nftItem.content}
              alt={nftItem.name}
              className="w-full h-full object-cover"
              onError={(e) => {
                (e.target as HTMLImageElement).src = FALLBACK_NFT;
              }}
            />
          ) : (
            <img src={FALLBACK_NFT} alt="NFT" className="w-full h-full object-cover" />
          )}
        </div>

        <div className="flex flex-col justify-center flex-1 min-w-0">
          <h3 className="text-sm font-semibold text-[var(--r-neutral-title-1)] truncate">
            {nftItem.name || 'Unnamed NFT'}
          </h3>
          <div className="flex items-center gap-1 mt-1">
            {chainInfo?.logo && (
              <img src={chainInfo.logo} alt="" className="w-3.5 h-3.5 rounded-full" />
            )}
            <span className="text-xs text-[var(--r-neutral-foot)]">
              {chainInfo?.name || nftItem.chain}
            </span>
          </div>
          <p className="text-xs text-[var(--r-neutral-foot)] mt-0.5 truncate">
            {ellipsisAddress(nftItem.contract_id)}
          </p>
        </div>
      </div>

      {isERC1155 && (
        <div className="flex items-center justify-between mt-4 pt-3 border-t border-[var(--r-neutral-line)]">
          <span className="text-sm text-[var(--r-neutral-body)]">Amount</span>
          <div className="flex items-center gap-3">
            <button
              className="w-8 h-8 rounded-lg border border-[var(--r-neutral-line)]
                flex items-center justify-center min-w-[44px] min-h-[44px]
                text-[var(--r-neutral-title-1)]"
              onClick={() => onAmountChange(Math.max(1, amount - 1))}
              disabled={amount <= 1}
            >
              -
            </button>
            <span className="text-sm font-semibold text-[var(--r-neutral-title-1)] w-8 text-center">
              {amount}
            </span>
            <button
              className="w-8 h-8 rounded-lg border border-[var(--r-neutral-line)]
                flex items-center justify-center min-w-[44px] min-h-[44px]
                text-[var(--r-neutral-title-1)]"
              onClick={() => onAmountChange(Math.min(nftItem.amount, amount + 1))}
              disabled={amount >= nftItem.amount}
            >
              +
            </button>
          </div>
          <span className="text-xs text-[var(--r-neutral-foot)]">/ {nftItem.amount}</span>
        </div>
      )}
    </div>
  );
};
