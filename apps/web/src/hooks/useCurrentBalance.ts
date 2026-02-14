import { useCallback, useEffect, useMemo, useState } from 'react';
import { useBalanceStore } from '../store/balance';
import { useAccountStore } from '../store/account';
import type { ChainBalance } from '../store/balance';

/**
 * Current balance hook.
 *
 * Returns the current account's total balance, chain balances,
 * and loading states. Automatically fetches balance when the
 * current account changes.
 *
 * Modeled after the extension's useCurrentBalance hook with
 * cache-first loading strategy.
 */
export function useCurrentBalance(
  account?: string,
  opts?: {
    noNeedBalance?: boolean;
    update?: boolean;
    nonce?: number;
  }
) {
  const {
    update = false,
    noNeedBalance = false,
    nonce = 0,
  } = opts || {};

  const currentAccountAddress = useAccountStore(
    (s) => s.currentAccount?.address
  );
  const address = account || currentAccountAddress;

  const totalBalance = useBalanceStore((s) => s.totalBalance);
  const evmBalance = useBalanceStore((s) => s.evmBalance);
  const chainBalances = useBalanceStore((s) => s.chainBalances);
  const matteredChainBalances = useBalanceStore(
    (s) => s.matteredChainBalances
  );
  const isLoading = useBalanceStore((s) => s.isLoading);
  const balanceFromCache = useBalanceStore((s) => s.balanceFromCache);
  const fetchBalance = useBalanceStore((s) => s.fetchBalance);

  const [success, setSuccess] = useState(true);
  const [missingList, setMissingList] = useState<string[]>();

  const getCurrentBalance = useCallback(
    async (force = false) => {
      if (!address || noNeedBalance) return;

      try {
        await fetchBalance(address);
        setSuccess(true);
      } catch (error) {
        console.error('[useCurrentBalance] error:', error);
        setSuccess(false);
      }
    },
    [address, noNeedBalance, fetchBalance]
  );

  const refresh = useCallback(async () => {
    await getCurrentBalance(true);
  }, [getCurrentBalance]);

  // Auto-fetch balance when address or nonce changes
  useEffect(() => {
    if (nonce < 0) return;
    getCurrentBalance();
  }, [address, nonce]);

  const chainBalancesWithValue = useMemo(() => {
    return matteredChainBalances.filter((chain) => chain.usdValue > 0);
  }, [matteredChainBalances]);

  return {
    balance: totalBalance,
    evmBalance,
    chainBalances,
    matteredChainBalances,
    chainBalancesWithValue,
    success,
    balanceLoading: isLoading,
    balanceFromCache,
    refreshBalance: refresh,
    fetchBalance: getCurrentBalance,
    missingList,
  };
}
