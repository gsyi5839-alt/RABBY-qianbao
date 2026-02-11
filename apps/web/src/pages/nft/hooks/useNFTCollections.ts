import { useApi } from '../../../hooks/useApi';
import { getNFTCollections } from '../../../services/api/nft';
import { useWallet } from '../../../contexts/WalletContext';
import type { NFTCollection } from '@rabby/shared';

export function useNFTCollections() {
  const { currentAccount } = useWallet();
  const address = currentAccount?.address;

  const { data, loading, error, refresh } = useApi<NFTCollection[]>(
    () => {
      if (!address) return Promise.resolve([]);
      return getNFTCollections(address);
    },
    [address],
  );

  return {
    collections: data ?? [],
    loading,
    error,
    refresh,
  };
}
