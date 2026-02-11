import { useApi } from './useApi';
import { getChainsList } from '../services/api/chains';
import type { Chain } from '@rabby/shared';

export function useChains() {
  const { data, loading, error, refresh } = useApi<Chain[]>(
    () => getChainsList(),
    [],
  );

  return {
    chains: data ?? [],
    loading,
    error,
    refresh,
  };
}
