import { useApi } from './useApi';
import { getTotalBalance, type BalanceResponse } from '../services/api/balance';
import { useWallet } from '../contexts/WalletContext';

export function useBalance() {
  const { currentAccount } = useWallet();
  const address = currentAccount?.address;

  const { data, loading, error, refresh } = useApi<BalanceResponse>(
    () => {
      if (!address) return Promise.resolve({ total_usd_value: 0, chain_list: [] });
      return getTotalBalance(address);
    },
    [address],
  );

  return {
    totalBalance: data?.total_usd_value ?? 0,
    chainBalances: data?.chain_list ?? [],
    loading,
    error,
    refresh,
  };
}
