import React, { useState, useMemo, useCallback } from 'react';
import { PageHeader } from '../../components/layout';
import { Input, Empty, Modal, Button, toast } from '../../components/ui';
import { useAccountStore } from '../../store';
import { ellipsisAddress, formatUsdValue } from '../../utils';
import type { Account } from '@rabby/shared';

// ---------------------------------------------------------------------------
// Address Management Page
// ---------------------------------------------------------------------------
const AddressManagementPage: React.FC = () => {
  const accounts = useAccountStore((s) => s.accounts);
  const currentAccount = useAccountStore((s) => s.currentAccount);
  const removeAccount = useAccountStore((s) => s.removeAccount);
  const switchAccount = useAccountStore((s) => s.switchAccount);

  const [search, setSearch] = useState('');
  const [editingAccount, setEditingAccount] = useState<Account | null>(null);
  const [editName, setEditName] = useState('');
  const [deleteTarget, setDeleteTarget] = useState<Account | null>(null);

  const filtered = useMemo(() => {
    if (!search.trim()) return accounts;
    const q = search.toLowerCase();
    return accounts.filter(
      (a) =>
        a.address.toLowerCase().includes(q) ||
        a.alianName?.toLowerCase().includes(q)
    );
  }, [accounts, search]);

  const handleStartEdit = useCallback((account: Account) => {
    setEditingAccount(account);
    setEditName(account.alianName || '');
  }, []);

  const handleSaveEdit = useCallback(() => {
    if (!editingAccount) return;
    // Update alias name in account store
    const store = useAccountStore.getState();
    const updated = store.accounts.map((a) =>
      a.address === editingAccount.address
        ? { ...a, alianName: editName }
        : a
    );
    store.setAccounts(updated);
    if (store.currentAccount?.address === editingAccount.address) {
      store.setAlianName(editName);
    }
    setEditingAccount(null);
    toast.success('Name updated');
  }, [editingAccount, editName]);

  const handleDelete = useCallback(() => {
    if (!deleteTarget) return;
    removeAccount(deleteTarget.address);
    setDeleteTarget(null);
    toast.success('Address removed');
  }, [deleteTarget, removeAccount]);

  const getTypeBadge = (type: string) => {
    const badges: Record<string, { label: string; color: string }> = {
      HD: { label: 'HD', color: 'bg-blue-100 text-blue-700' },
      'Simple Key Pair': { label: 'Imported', color: 'bg-green-100 text-green-700' },
      WatchAddress: { label: 'Watch', color: 'bg-gray-100 text-gray-600' },
    };
    return badges[type] || { label: type, color: 'bg-gray-100 text-gray-600' };
  };

  return (
    <div className="min-h-screen bg-[var(--r-neutral-bg-1)] flex flex-col">
      <PageHeader title="Address Management" />

      {/* Search */}
      <div className="px-4 pb-3">
        <Input
          placeholder="Search address or name..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          prefix={<SearchIcon />}
        />
      </div>

      {/* Address list */}
      <div className="flex-1 overflow-y-auto px-4 pb-4">
        {filtered.length === 0 ? (
          <Empty description="No addresses found" />
        ) : (
          <div className="flex flex-col gap-2">
            {filtered.map((account) => {
              const badge = getTypeBadge(account.type);
              const isCurrent =
                currentAccount?.address === account.address;

              return (
                <div
                  key={account.address}
                  className="bg-[var(--r-neutral-card-1)] rounded-xl px-4 py-3 flex items-center gap-3"
                >
                  {/* Indicator */}
                  <div
                    className={`w-2 h-2 rounded-full flex-shrink-0 ${
                      isCurrent
                        ? 'bg-[var(--r-green-default)]'
                        : 'bg-transparent'
                    }`}
                  />

                  {/* Info */}
                  <button
                    className="flex-1 min-w-0 text-left"
                    onClick={() => switchAccount(account)}
                  >
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-medium text-[var(--r-neutral-title-1)] truncate">
                        {account.alianName || 'Unnamed'}
                      </span>
                      <span
                        className={`text-[10px] px-1.5 py-0.5 rounded font-medium ${badge.color}`}
                      >
                        {badge.label}
                      </span>
                    </div>
                    <div className="text-xs text-[var(--r-neutral-foot)] mt-0.5">
                      {ellipsisAddress(account.address)}
                    </div>
                    {account.balance != null && (
                      <div className="text-xs text-[var(--r-neutral-body)] mt-0.5">
                        {formatUsdValue(account.balance)}
                      </div>
                    )}
                  </button>

                  {/* Actions */}
                  <div className="flex gap-1 flex-shrink-0">
                    <button
                      className="p-2 min-w-[44px] min-h-[44px] flex items-center justify-center"
                      onClick={() => handleStartEdit(account)}
                    >
                      <EditIcon />
                    </button>
                    <button
                      className="p-2 min-w-[44px] min-h-[44px] flex items-center justify-center text-[var(--r-red-default)]"
                      onClick={() => setDeleteTarget(account)}
                    >
                      <DeleteIcon />
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Edit name modal */}
      <Modal
        visible={!!editingAccount}
        onClose={() => setEditingAccount(null)}
        title="Edit Name"
        footer={
          <div className="flex gap-3">
            <Button variant="ghost" fullWidth onClick={() => setEditingAccount(null)}>
              Cancel
            </Button>
            <Button variant="primary" fullWidth onClick={handleSaveEdit}>
              Save
            </Button>
          </div>
        }
      >
        <Input
          label="Address Name"
          value={editName}
          onChange={(e) => setEditName(e.target.value)}
          placeholder="Enter name..."
          autoFocus
        />
      </Modal>

      {/* Delete confirmation modal */}
      <Modal
        visible={!!deleteTarget}
        onClose={() => setDeleteTarget(null)}
        title="Remove Address"
        footer={
          <div className="flex gap-3">
            <Button variant="ghost" fullWidth onClick={() => setDeleteTarget(null)}>
              Cancel
            </Button>
            <Button variant="danger" fullWidth onClick={handleDelete}>
              Remove
            </Button>
          </div>
        }
      >
        <p className="text-sm text-[var(--r-neutral-body)]">
          Are you sure you want to remove this address?
        </p>
        {deleteTarget && (
          <p className="text-sm font-mono text-[var(--r-neutral-foot)] mt-2">
            {ellipsisAddress(deleteTarget.address)}
          </p>
        )}
      </Modal>
    </div>
  );
};

export default AddressManagementPage;

// ---------------------------------------------------------------------------
// Icons
// ---------------------------------------------------------------------------
const SearchIcon = () => (
  <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
    <circle cx="7" cy="7" r="5" stroke="currentColor" strokeWidth="1.5" />
    <path d="M11 11l3 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
  </svg>
);

const EditIcon = () => (
  <svg width="16" height="16" viewBox="0 0 16 16" fill="none" className="text-[var(--r-neutral-foot)]">
    <path d="M10 3l3 3-8 8H2v-3l8-8z" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round" />
  </svg>
);

const DeleteIcon = () => (
  <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
    <path d="M4 5h8l-.7 7.3a1 1 0 01-1 .7H5.7a1 1 0 01-1-.7L4 5z" stroke="currentColor" strokeWidth="1.3" />
    <path d="M3 5h10M6 5V3h4v2" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
  </svg>
);
