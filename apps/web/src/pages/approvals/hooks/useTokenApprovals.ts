import { useApi } from '../../../hooks/useApi';
import { getTokenApprovals } from '../../../services/api/approval';
import { useWallet } from '../../../contexts/WalletContext';
import type { TokenApproval } from '@rabby/shared';

export function useTokenApprovals() {
  const { currentAccount } = useWallet();
  const address = currentAccount?.address;

  const { data, loading, error, refresh } = useApi<TokenApproval[]>(
    () => {
      if (!address) return Promise.resolve([]);
      return getTokenApprovals(address);
    },
    [address],
  );

  return {
    approvals: data ?? [],
    loading,
    error,
    refresh,
  };
}
