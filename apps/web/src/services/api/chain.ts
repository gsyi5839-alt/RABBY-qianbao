/**
 * Chain API Service
 *
 * Wraps Rabby OpenAPI chain-related endpoints.
 * Reference: OpenApiService.getChainList, getSupportedChains, gasMarket,
 *            searchChainList, usedChainList
 */

import type { ApiClient } from './client';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types (aligned with @rabby-wallet/rabby-api types)
// ---------------------------------------------------------------------------

export interface ServerChain {
  id: string;
  community_id: number;
  name: string;
  native_token_id: string;
  logo_url: string;
  wrapped_token_id: string;
  symbol: string;
  is_support_history: boolean;
  born_at: number | null;
}

export interface SupportedChain {
  id: string;
  community_id: number;
  name: string;
  native_token: {
    id: string;
    symbol: string;
    logo: string;
    decimals: number;
  };
  logo_url: string;
  white_logo_url?: string;
  need_estimate_gas?: boolean;
  eip_1559: boolean;
  is_disabled: boolean;
  explorer_host: string;
  block_interval: number;
  severity?: number;
}

export interface ChainListItem {
  chain_id: number;
  name: string;
  short_name: string;
  native_currency: {
    name: string;
    symbol: string;
    decimals: number;
  };
  explorer: string | null;
  rpc: string | null;
  rpc_list?: string[];
}

export interface GasLevel {
  level: string;
  price: number;
  front_tx_count: number;
  estimated_seconds: number;
  priority_price: number | null;
  base_fee: number;
}

export interface UsedChain {
  id: string;
  community_id: number;
  name: string;
  native_token_id: string;
  logo_url: string;
  wrapped_token_id: string;
}

// ---------------------------------------------------------------------------
// Chain API
// ---------------------------------------------------------------------------

export interface ChainApi {
  /**
   * Get all chains supported by Rabby wallet.
   * Maps to: GET /v1/wallet/supported_chains
   */
  getSupportedChains(): Promise<SupportedChain[]>;

  /**
   * Get the full chain list (server chains).
   * Maps to: GET /v1/chain/list
   */
  getChainList(): Promise<ServerChain[]>;

  /**
   * Get gas prices for a specific chain.
   * Maps to: GET /v1/wallet/gas_market?chain_id={chainId}
   */
  getChainGasPrice(
    chainId: string,
    customGas?: number,
  ): Promise<GasLevel[]>;

  /**
   * Search through the extended chain list (EVM chains registry).
   * Maps to: GET /v1/chain/search_list?q={query}
   */
  searchChainList(params?: {
    limit?: number;
    start?: number;
    q?: string;
  }): Promise<{
    page: { start: number; limit: number; total: number };
    chain_list: ChainListItem[];
  }>;

  /**
   * Get chains the user has interacted with.
   * Maps to: GET /v1/user/used_chain_list?id={address}
   */
  getUsedChainList(address: string): Promise<UsedChain[]>;

  /**
   * Get gas price stats (median) for a chain.
   * Maps to: GET /v1/wallet/gas_price_stats?chain_id={chainId}
   */
  getGasPriceStats(chainId: string): Promise<{ median: number }>;
}

export function createChainApi(client: ApiClient = apiClient): ChainApi {
  return {
    async getSupportedChains(): Promise<SupportedChain[]> {
      return client.get<SupportedChain[]>('/v1/wallet/supported_chains');
    },

    async getChainList(): Promise<ServerChain[]> {
      return client.get<ServerChain[]>('/v1/chain/list');
    },

    async getChainGasPrice(
      chainId: string,
      customGas?: number,
    ): Promise<GasLevel[]> {
      return client.get<GasLevel[]>('/v1/wallet/gas_market', {
        chain_id: chainId,
        custom_gas: customGas,
      });
    },

    async searchChainList(
      params?: { limit?: number; start?: number; q?: string },
    ): Promise<{
      page: { start: number; limit: number; total: number };
      chain_list: ChainListItem[];
    }> {
      return client.get('/v1/chain/search_list', params);
    },

    async getUsedChainList(address: string): Promise<UsedChain[]> {
      return client.get<UsedChain[]>('/v1/user/used_chain_list', {
        id: address,
      });
    },

    async getGasPriceStats(chainId: string): Promise<{ median: number }> {
      return client.get('/v1/wallet/gas_price_stats', {
        chain_id: chainId,
      });
    },
  };
}

/** Default singleton chain API instance */
export const chainApi = createChainApi();
