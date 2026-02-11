import { useApi } from './useApi';
import { getTokenList, type TokenListResponse } from '../services/api/tokens';
import { useWallet } from '../contexts/WalletContext';

export function useTokenList(chain?: string) {
  const { currentAccount } = useWallet();
  const address = currentAccount?.address;

  const { data, loading, error, refresh } = useApi<TokenListResponse>(
    () => {
      if (!address) return Promise.resolve({ tokens: [] });
      return getTokenList(address, chain);
    },
    [address, chain],
  );

  return {
    tokens: data?.tokens ?? [],
    loading,
    error,
    refresh,
  };
}
