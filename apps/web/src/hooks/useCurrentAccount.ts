import { useMemo } from 'react';
import { useAccountStore } from '../store/account';
import type { Account } from '@rabby/shared';

/**
 * Returns the current account info from store.
 *
 * Provides a simple interface to access the current account
 * and its alias name. Automatically re-renders when the
 * current account changes in the store.
 *
 * Modeled after the extension's useCurrentAccount / useAccount hooks.
 */
export function useCurrentAccount(): {
  currentAccount: Account | null;
  alianName: string;
  address: string | undefined;
} {
  const currentAccount = useAccountStore((s) => s.currentAccount);
  const alianName = useAccountStore((s) => s.alianName);

  const address = useMemo(
    () => currentAccount?.address,
    [currentAccount?.address]
  );

  return {
    currentAccount,
    alianName,
    address,
  };
}

/**
 * Selector hook that returns just the current account address.
 * Useful when you only need the address string and want minimal re-renders.
 */
export function useCurrentAddress(): string | undefined {
  return useAccountStore((s) => s.currentAccount?.address);
}
