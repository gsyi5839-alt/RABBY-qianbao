import React, { useState, useCallback, useMemo } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import clsx from 'clsx';
import { useCurrentAccount, useContact } from '../../hooks';
import { useAccountStore } from '../../store/account';
import { PageHeader } from '../../components/layout';
import { Input } from '../../components/ui';
import { isValidAddress, isSameAddress } from '../../utils';
import { AddressList } from './AddressList';
import type { AddressEntry } from './AddressList';

type TabKey = 'recent' | 'contacts' | 'accounts';

const TABS: { key: TabKey; label: string }[] = [
  { key: 'recent', label: 'Recent' },
  { key: 'contacts', label: 'Contacts' },
  { key: 'accounts', label: 'My Accounts' },
];

const EMPTY_TEXT: Record<TabKey, string> = {
  recent: 'No recent addresses',
  contacts: 'No contacts yet',
  accounts: 'No other accounts',
};

export const SelectToAddressPage: React.FC = () => {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const { address: currentAddress } = useCurrentAccount();
  const accounts = useAccountStore((s) => s.accounts);
  const { contacts } = useContact();

  const [activeTab, setActiveTab] = useState<TabKey>('contacts');
  const [search, setSearch] = useState('');
  const [manualAddress, setManualAddress] = useState('');

  const sendType = searchParams.get('type') || 'send-token';

  const contactList = useMemo<AddressEntry[]>(
    () => contacts.map((c) => ({ address: c.address, name: c.name })),
    [contacts]
  );

  const accountList = useMemo<AddressEntry[]>(
    () =>
      accounts
        .filter((a) => !isSameAddress(a.address, currentAddress || ''))
        .map((a) => ({
          address: a.address,
          name: a.alianName || a.brandName || 'Account',
          type: a.type,
        })),
    [accounts, currentAddress]
  );

  // TODO: Pull from transaction history store when available
  const recentList = useMemo<AddressEntry[]>(() => [], []);

  const currentList = useMemo(() => {
    const lists: Record<TabKey, AddressEntry[]> = {
      recent: recentList,
      contacts: contactList,
      accounts: accountList,
    };
    const list = lists[activeTab];
    if (!search.trim()) return list;
    const q = search.toLowerCase();
    return list.filter(
      (item) =>
        item.name.toLowerCase().includes(q) ||
        item.address.toLowerCase().includes(q)
    );
  }, [activeTab, recentList, contactList, accountList, search]);

  const handleBack = useCallback(() => navigate(-1), [navigate]);

  const handleSelectAddress = useCallback(
    (address: string, type?: string) => {
      const params = new URLSearchParams(searchParams.toString());
      params.set('to', address);
      if (type) params.set('addressType', type);
      const path = sendType === 'send-nft' ? '/send-nft' : '/send-token';
      navigate(`${path}?${params.toString()}`, { replace: true });
    },
    [navigate, searchParams, sendType]
  );

  const handleManualSubmit = useCallback(() => {
    const addr = manualAddress.trim();
    if (addr && isValidAddress(addr)) handleSelectAddress(addr);
  }, [manualAddress, handleSelectAddress]);

  const isManualValid = manualAddress ? isValidAddress(manualAddress) : true;

  return (
    <div className="min-h-screen bg-[var(--r-neutral-bg-1)] flex flex-col">
      <PageHeader title="Send To" onBack={handleBack} />

      <div className="px-4 pb-3">
        <div className="mb-3">
          <Input
            value={manualAddress}
            onChange={(e) => setManualAddress(e.target.value.trim())}
            placeholder="Enter address or ENS name"
            error={!isManualValid ? 'Invalid address format' : undefined}
            suffix={
              manualAddress && isManualValid ? (
                <button
                  className="text-xs font-medium text-[var(--rabby-brand)] min-w-[44px] min-h-[28px]"
                  onClick={handleManualSubmit}
                >
                  Confirm
                </button>
              ) : undefined
            }
          />
        </div>
        <Input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search name or address"
          prefix={<SearchIcon />}
        />
      </div>

      {/* Tabs */}
      <div className="flex border-b border-[var(--r-neutral-line)] px-4">
        {TABS.map((tab) => (
          <button
            key={tab.key}
            className={clsx(
              'flex-1 py-3 text-sm font-medium text-center transition-colors min-h-[44px] relative',
              activeTab === tab.key
                ? 'text-[var(--r-neutral-title-1)]'
                : 'text-[var(--r-neutral-foot)]'
            )}
            onClick={() => setActiveTab(tab.key)}
          >
            {tab.label}
            {activeTab === tab.key && (
              <div className="absolute bottom-0 left-1/4 right-1/4 h-0.5 bg-[var(--rabby-brand)] rounded-full" />
            )}
          </button>
        ))}
      </div>

      {/* Address list */}
      <div className="flex-1 overflow-y-auto px-4 pt-2">
        <AddressList
          entries={currentList}
          emptyText={EMPTY_TEXT[activeTab]}
          onSelect={handleSelectAddress}
        />
      </div>
    </div>
  );
};

const SearchIcon = () => (
  <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
    <circle cx="7" cy="7" r="5" stroke="currentColor" strokeWidth="1.5" />
    <path d="M11 11l3 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
  </svg>
);
