// Deprecated: use imports from './api/' directly
export * from './api';

// Keep legacy api object for backwards compat
import { getChainsList } from './api/chains';
import { getTxHistory } from './api/history';
import { getSwapQuote } from './api/swap';
import { getBridgeQuotes } from './api/bridge';
import { apiGet } from './client';

export const api = {
  getHealth: () => apiGet<{ status: string }>('/health'),
  getChainsConfig: () => apiGet('/api/chains/config'),
  getChainsList: () => getChainsList(),
  getSwapQuote: (params: { fromToken: string; toToken: string; amount: string; chainId?: string }) =>
    getSwapQuote(params),
  getBridgeRoutes: (params: { fromChain: string; toChain: string; token?: string; amount?: string }) =>
    getBridgeQuotes({ fromChain: params.fromChain, toChain: params.toChain, fromToken: params.token || '', toToken: '', amount: params.amount || '0', fromAddress: '' }),
  getHistory: (address: string, params?: { chainId?: string; page?: number; limit?: number }) =>
    getTxHistory(address, { chain: params?.chainId, page: params?.page, limit: params?.limit }),
  getDappsList: (q?: string) => apiGet('/api/dapps/list', q ? { q } : undefined),
};
