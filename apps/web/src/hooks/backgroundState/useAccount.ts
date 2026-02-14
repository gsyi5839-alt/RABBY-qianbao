import { useCallback, useEffect, useMemo } from 'react';
import { useAccountStore } from '../../store/account';
import type { Account } from '@rabby/shared';

/**
 * Background account state hook.
 *
 * Provides the current account state that persists across
 * navigation and background updates. Handles account change
 * events and alias name synchronization.
 *
 * Modeled after the extension's backgroundState/useAccount hook,
 * adapted for the web app where there is no true "background page"
 * but we still need to maintain consistent account state.
 */
export function useAccount(options?: {
  onChanged?: (ctx: {
    reason: 'aliasName' | 'currentAccount';
    address: string;
  }) => void;
}) {
  const currentAccount = useAccountStore((s) => s.currentAccount);
  const accounts = useAccountStore((s) => s.accounts);
  const alianName = useAccountStore((s) => s.alianName);
  const isLocked = useAccountStore((s) => s.isLocked);
  const setCurrentAccount = useAccountStore((s) => s.setCurrentAccount);
  const setAlianName = useAccountStore((s) => s.setAlianName);

  const { onChanged } = options || {};

  /**
   * Subscribe to account store changes and invoke callback.
   * In the extension, this listens to broadcastToUI events.
   * In the web app, we use Zustand subscriptions.
   */
  useEffect(() => {
    const unsub = useAccountStore.subscribe(
      (state, prevState) => {
        // Current account changed
        if (
          state.currentAccount?.address !==
          prevState.currentAccount?.address
        ) {
          onChanged?.({
            reason: 'currentAccount',
            address: state.currentAccount?.address || '',
          });
        }

        // Alias name changed for current account
        if (
          state.alianName !== prevState.alianName &&
          state.currentAccount?.address
        ) {
          onChanged?.({
            reason: 'aliasName',
            address: state.currentAccount.address,
          });
        }
      }
    );

    return unsub;
  }, [onChanged]);

  const switchAccount = useCallback(
    (account: Account) => {
      setCurrentAccount(account);
      setAlianName(account.alianName || '');
      // TODO: Persist account switch to backend when available
    },
    [setCurrentAccount, setAlianName]
  );

  const visibleAccounts = useMemo(() => {
    const hiddenAddresses = useAccountStore.getState().hiddenAddresses;
    return accounts.filter(
      (a) => !hiddenAddresses.includes(a.address.toLowerCase())
    );
  }, [accounts]);

  return {
    currentAccount,
    accounts,
    visibleAccounts,
    alianName,
    isLocked,
    switchAccount,
  };
}
