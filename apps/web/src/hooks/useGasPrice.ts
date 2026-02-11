import { useApi } from './useApi';
import { apiGet } from '../services/client';

interface GasPriceResponse {
  slow: string;
  normal: string;
  fast: string;
  base_fee?: string;
}

export function useGasPrice(chainId?: number) {
  const { data, loading, error, refresh } = useApi<GasPriceResponse>(
    () => {
      if (!chainId) return Promise.resolve({ slow: '0', normal: '0', fast: '0' });
      return apiGet<GasPriceResponse>('/api/gas/price', { chainId });
    },
    [chainId],
  );

  return {
    gasPrice: data,
    loading,
    error,
    refresh,
  };
}
