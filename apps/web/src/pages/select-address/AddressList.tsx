import React from 'react';
import clsx from 'clsx';
import { ellipsisAddress } from '../../utils';
import { Empty } from '../../components/ui';

export interface AddressEntry {
  address: string;
  name: string;
  type?: string;
}

interface AddressListProps {
  entries: AddressEntry[];
  emptyText: string;
  onSelect: (address: string, type?: string) => void;
}

export const AddressList: React.FC<AddressListProps> = ({
  entries,
  emptyText,
  onSelect,
}) => {
  if (entries.length === 0) {
    return (
      <div className="py-10">
        <Empty description={emptyText} />
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-1">
      {entries.map((entry) => (
        <button
          key={entry.address}
          className="flex items-center gap-3 px-3 py-3 rounded-xl
            hover:bg-[var(--r-neutral-bg-2)] transition-colors min-h-[56px]"
          onClick={() => onSelect(entry.address, entry.type)}
        >
          <div className="w-8 h-8 rounded-full bg-[var(--r-blue-light-1)]
            flex items-center justify-center flex-shrink-0">
            <span className="text-xs font-bold text-[var(--rabby-brand)]">
              {(entry.name || '?')[0].toUpperCase()}
            </span>
          </div>
          <div className="flex flex-col items-start flex-1 min-w-0">
            <span className="text-sm font-medium text-[var(--r-neutral-title-1)] truncate max-w-full">
              {entry.name}
            </span>
            <span className="text-xs text-[var(--r-neutral-foot)] font-mono">
              {ellipsisAddress(entry.address)}
            </span>
          </div>
          <ArrowRightIcon />
        </button>
      ))}
    </div>
  );
};

const ArrowRightIcon = () => (
  <svg
    width="16"
    height="16"
    viewBox="0 0 16 16"
    fill="none"
    className="text-[var(--r-neutral-foot)] flex-shrink-0"
  >
    <path
      d="M6 4l4 4-4 4"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);
