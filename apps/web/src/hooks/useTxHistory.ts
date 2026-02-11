import { useState, useCallback } from 'react';
import { useApi } from './useApi';
import { getTxHistory, type TxHistoryResponse } from '../services/api/history';
import { useWallet } from '../contexts/WalletContext';

export function useTxHistory(chain?: string, limit = 20) {
  const { currentAccount } = useWallet();
  const address = currentAccount?.address;
  const [page, setPage] = useState(1);

  const { data, loading, error, refresh } = useApi<TxHistoryResponse>(
    () => {
      if (!address) return Promise.resolve({ history_list: [], total: 0 });
      return getTxHistory(address, { chain, page, limit });
    },
    [address, chain, page, limit],
  );

  const nextPage = useCallback(() => {
    setPage((p) => p + 1);
  }, []);

  const prevPage = useCallback(() => {
    setPage((p) => Math.max(1, p - 1));
  }, []);

  const goToPage = useCallback((n: number) => {
    setPage(Math.max(1, n));
  }, []);

  return {
    history: data?.history_list ?? [],
    total: data?.total ?? 0,
    page,
    loading,
    error,
    refresh,
    nextPage,
    prevPage,
    goToPage,
  };
}
