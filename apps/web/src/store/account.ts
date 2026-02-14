import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { Account } from '@rabby/shared';

export interface AccountStore {
  // State
  currentAccount: Account | null;
  accounts: Account[];
  alianName: string;
  isLocked: boolean;
  hiddenAddresses: string[];

  // Actions
  setCurrentAccount: (account: Account | null) => void;
  setAccounts: (accounts: Account[]) => void;
  addAccount: (account: Account) => void;
  removeAccount: (address: string) => void;
  setAlianName: (name: string) => void;
  setHiddenAddresses: (addresses: string[]) => void;
  lock: () => void;
  unlock: () => void;
  switchAccount: (account: Account) => void;
  reset: () => void;
}

const initialState = {
  currentAccount: null as Account | null,
  accounts: [] as Account[],
  alianName: '',
  isLocked: true,
  hiddenAddresses: [] as string[],
};

export const useAccountStore = create<AccountStore>()(
  persist(
    (set, get) => ({
      ...initialState,

      setCurrentAccount: (account) => {
        set({ currentAccount: account });
      },

      setAccounts: (accounts) => {
        set({ accounts });
      },

      addAccount: (account) => {
        const { accounts } = get();
        const exists = accounts.some(
          (a) => a.address.toLowerCase() === account.address.toLowerCase()
        );
        if (!exists) {
          set({ accounts: [...accounts, account] });
        }
      },

      removeAccount: (address) => {
        const { accounts, currentAccount } = get();
        const filtered = accounts.filter(
          (a) => a.address.toLowerCase() !== address.toLowerCase()
        );
        set({ accounts: filtered });

        // If removing the current account, switch to first available or null
        if (
          currentAccount &&
          currentAccount.address.toLowerCase() === address.toLowerCase()
        ) {
          set({ currentAccount: filtered[0] || null });
        }
      },

      setAlianName: (name) => {
        set({ alianName: name });
      },

      setHiddenAddresses: (addresses) => {
        set({ hiddenAddresses: addresses });
      },

      lock: () => {
        set({ isLocked: true });
      },

      unlock: () => {
        set({ isLocked: false });
      },

      switchAccount: (account) => {
        set({ currentAccount: account, alianName: account.alianName || '' });
      },

      reset: () => {
        set(initialState);
      },
    }),
    {
      name: 'rabby-account-store',
      partialize: (state) => ({
        currentAccount: state.currentAccount,
        accounts: state.accounts,
        hiddenAddresses: state.hiddenAddresses,
      }),
    }
  )
);
