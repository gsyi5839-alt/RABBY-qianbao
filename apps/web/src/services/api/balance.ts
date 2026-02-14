/**
 * Balance API Service
 *
 * Wraps Rabby OpenAPI balance-related endpoints.
 * Reference: OpenApiService.getTotalBalance, listToken, listChainAssets
 */

import type { ApiClient } from './client';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types (aligned with @rabby-wallet/rabby-api types & @rabby/shared)
// ---------------------------------------------------------------------------

export interface ChainWithBalance {
  id: string;
  community_id: number;
  name: string;
  native_token_id: string;
  logo_url: string;
  wrapped_token_id: string;
  symbol: string;
  is_support_history: boolean;
  born_at: number | null;
  usd_value: number;
}

export interface TotalBalanceResponse {
  total_usd_value: number;
  chain_list: ChainWithBalance[];
  error_code?: number;
  err_chain_ids?: string[];
}

export interface TokenItem {
  id: string;
  chain: string;
  name: string;
  symbol: string;
  display_symbol: string | null;
  optimized_symbol: string;
  decimals: number;
  logo_url: string;
  price: number;
  amount: number;
  raw_amount?: string;
  raw_amount_hex_str?: string;
  is_verified: boolean | null;
  is_core: boolean | null;
  is_scam?: boolean;
  is_suspicious?: boolean;
  is_wallet: boolean;
  time_at: number;
  usd_value?: number;
  price_24h_change?: number | null;
}

export interface AssetItem {
  id: string;
  chain: string;
  name: string;
  site_url: string;
  logo_url: string;
  has_supported_portfolio: boolean;
  tvl: number;
  net_usd_value: number;
  asset_usd_value: number;
  debt_usd_value: number;
}

// ---------------------------------------------------------------------------
// Balance API
// ---------------------------------------------------------------------------

export interface BalanceApi {
  /**
   * Get total USD balance for an address across all chains.
   * Maps to: GET /v1/user/total_balance?id={address}
   */
  getTotalBalance(address: string): Promise<TotalBalanceResponse>;

  /**
   * Get per-chain asset breakdown for an address.
   * Maps to: GET /v1/user/chain_balance?id={address}
   */
  getChainBalance(address: string, chainId?: string): Promise<AssetItem[]>;

  /**
   * Get token list for an address, optionally filtered by chain.
   * Maps to: GET /v1/user/token_list?id={address}&chain_id={chainId}&is_all={isAll}
   */
  getTokenList(
    address: string,
    chainId?: string,
    isAll?: boolean,
  ): Promise<TokenItem[]>;

  /**
   * Get the current price for a given token symbol / name.
   * Maps to: GET /v1/token/price?token={tokenName}
   */
  getTokenPrice(
    tokenName: string,
  ): Promise<{ change_percent: number; last_price: number }>;
}

export function createBalanceApi(client: ApiClient = apiClient): BalanceApi {
  return {
    async getTotalBalance(address: string): Promise<TotalBalanceResponse> {
      return client.get<TotalBalanceResponse>('/v1/user/total_balance', {
        id: address,
      });
    },

    async getChainBalance(
      address: string,
      chainId?: string,
    ): Promise<AssetItem[]> {
      return client.get<AssetItem[]>('/v1/user/chain_balance', {
        id: address,
        chain_id: chainId,
      });
    },

    async getTokenList(
      address: string,
      chainId?: string,
      isAll?: boolean,
    ): Promise<TokenItem[]> {
      return client.get<TokenItem[]>('/v1/user/token_list', {
        id: address,
        chain_id: chainId,
        is_all: isAll,
      });
    },

    async getTokenPrice(
      tokenName: string,
    ): Promise<{ change_percent: number; last_price: number }> {
      return client.get('/v1/token/price', { token: tokenName });
    },
  };
}

/** Default singleton balance API instance */
export const balanceApi = createBalanceApi();
