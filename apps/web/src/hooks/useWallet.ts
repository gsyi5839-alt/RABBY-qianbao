import { useCallback, useMemo } from 'react';
import { useAccountStore } from '../store/account';
import { usePreferenceStore } from '../store/preference';
import type { Account } from '@rabby/shared';

/**
 * Core wallet operations hook.
 *
 * Encapsulates wallet lock/unlock, account management,
 * and high-level wallet operations. This is the primary
 * hook for interacting with the wallet state.
 *
 * Modeled after the extension's wallet controller pattern,
 * adapted for Zustand-based state management.
 */
export function useWallet() {
  const {
    isLocked,
    currentAccount,
    accounts,
    setCurrentAccount,
    lock,
    unlock: storeUnlock,
    switchAccount: storeSwitchAccount,
    addAccount: storeAddAccount,
    removeAccount: storeRemoveAccount,
    setAlianName,
  } = useAccountStore();

  const { autoLockTime } = usePreferenceStore();

  const unlock = useCallback(
    async (password: string): Promise<boolean> => {
      try {
        // TODO: Call keyring unlock service when available
        // const success = await keyringService.unlock(password);
        // if (success) { storeUnlock(); }
        // return success;
        storeUnlock();
        return true;
      } catch (error) {
        console.error('[useWallet] unlock error:', error);
        return false;
      }
    },
    [storeUnlock]
  );

  const lockWallet = useCallback(() => {
    lock();
    // TODO: Call keyring lock service when available
    // keyringService.lock();
  }, [lock]);

  const getCurrentAccount = useCallback((): Account | null => {
    return currentAccount;
  }, [currentAccount]);

  const switchAccount = useCallback(
    (account: Account) => {
      storeSwitchAccount(account);
      // TODO: Persist switch to backend when available
      // walletService.changeAccount(account);
    },
    [storeSwitchAccount]
  );

  const addAccount = useCallback(
    (account: Account) => {
      storeAddAccount(account);
    },
    [storeAddAccount]
  );

  const removeAccount = useCallback(
    (address: string) => {
      storeRemoveAccount(address);
    },
    [storeRemoveAccount]
  );

  const updateAlianName = useCallback(
    async (address: string, name: string) => {
      // TODO: Persist alias name to backend when available
      // await walletService.updateAlianName(address, name);
      if (
        currentAccount &&
        currentAccount.address.toLowerCase() === address.toLowerCase()
      ) {
        setAlianName(name);
      }
    },
    [currentAccount, setAlianName]
  );

  const visibleAccounts = useMemo(() => {
    const hiddenAddresses = useAccountStore.getState().hiddenAddresses;
    return accounts.filter(
      (a) => !hiddenAddresses.includes(a.address.toLowerCase())
    );
  }, [accounts]);

  return {
    // State
    isLocked,
    currentAccount,
    accounts,
    visibleAccounts,
    autoLockTime,

    // Actions
    lock: lockWallet,
    unlock,
    getCurrentAccount,
    switchAccount,
    addAccount,
    removeAccount,
    updateAlianName,
  };
}
