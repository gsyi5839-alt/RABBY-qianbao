import React from 'react';
import type { NFTItem } from '@rabby/shared';
import { Popup } from '../../../components/ui';
import { Button } from '../../../components/ui';
import { useNavigate } from 'react-router-dom';

interface NFTDetailPopupProps {
  nft: NFTItem | null;
  visible: boolean;
  onClose: () => void;
}

export const NFTDetailPopup: React.FC<NFTDetailPopupProps> = ({
  nft,
  visible,
  onClose,
}) => {
  const navigate = useNavigate();

  if (!nft) return null;

  const explorerUrl = nft.detail_url
    || `https://etherscan.io/token/${nft.contract_id}?a=${nft.inner_id}`;

  return (
    <Popup visible={visible} onClose={onClose} height="85vh">
      <div className="flex flex-col gap-4 pb-4">
        {/* Full-size image */}
        <div className="w-full aspect-square rounded-xl overflow-hidden bg-[var(--r-neutral-line)]">
          {nft.content ? (
            <img
              src={nft.content}
              alt={nft.name}
              className="w-full h-full object-contain"
            />
          ) : (
            <div className="w-full h-full flex items-center justify-center text-[var(--r-neutral-foot)]">
              No preview
            </div>
          )}
        </div>

        {/* Name */}
        <h3 className="text-lg font-semibold text-[var(--r-neutral-title-1)]">
          {nft.name}
        </h3>

        {/* Description */}
        {nft.description && (
          <p className="text-sm text-[var(--r-neutral-body)] leading-relaxed">
            {nft.description}
          </p>
        )}

        {/* Properties */}
        <div className="grid grid-cols-2 gap-2">
          <PropertyCard label="Token ID" value={`#${nft.inner_id}`} />
          <PropertyCard label="Chain" value={nft.chain.toUpperCase()} />
          <PropertyCard label="Standard" value={nft.amount > 1 ? 'ERC-1155' : 'ERC-721'} />
          {nft.amount > 1 && (
            <PropertyCard label="Amount" value={String(nft.amount)} />
          )}
        </div>

        {/* Actions */}
        <div className="flex gap-3 mt-2">
          <Button
            variant="primary"
            size="lg"
            fullWidth
            onClick={() => {
              onClose();
              navigate('/send-nft');
            }}
          >
            Send
          </Button>
          <Button
            variant="secondary"
            size="lg"
            fullWidth
            onClick={() => window.open(explorerUrl, '_blank')}
          >
            View on Explorer
          </Button>
        </div>
      </div>
    </Popup>
  );
};

// ---------------------------------------------------------------------------
// Property card
// ---------------------------------------------------------------------------
interface PropertyCardProps {
  label: string;
  value: string;
}

const PropertyCard: React.FC<PropertyCardProps> = ({ label, value }) => (
  <div className="bg-[var(--r-neutral-bg-2)] rounded-lg px-3 py-2">
    <div className="text-xs text-[var(--r-neutral-foot)] mb-0.5">{label}</div>
    <div className="text-sm font-medium text-[var(--r-neutral-title-1)] truncate">
      {value}
    </div>
  </div>
);
