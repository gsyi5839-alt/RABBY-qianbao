import React from 'react';

interface AddressViewerProps {
  address: string;
  showFull?: boolean;
  className?: string;
}

export function AddressViewer({ address, showFull = false, className = '' }: AddressViewerProps) {
  const display = showFull ? address : `${address.slice(0, 6)}...${address.slice(-4)}`;
  return (
    <span className={`address-text ${className}`} title={address}>
      {display}
    </span>
  );
}
