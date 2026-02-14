/**
 * Token API Service
 *
 * Wraps Rabby OpenAPI token-related endpoints.
 * Reference: OpenApiService.searchToken, getToken, customListToken, listToken
 */

import type { ApiClient } from './client';
import { apiClient } from './client';
import type { TokenItem } from './balance';

// ---------------------------------------------------------------------------
// Additional Token Types
// ---------------------------------------------------------------------------

export type { TokenItem } from './balance';

export interface TokenEntityDetail {
  id: string;
  chain: string;
  token_id: string;
  symbol: string;
  domain_id: string;
  fdv: number;
  is_domain_verified: boolean;
  relate_domain_ids: string[];
  cmc_id: string;
  coingecko_id: string;
  bridge_ids: string[];
  origin_token?: TokenItem;
  tag_ids?: string[];
  listed_sites: Array<{ name: string; url: string; logo_url: string }>;
  cex_list: Array<{
    id: string;
    site_url: string;
    name: string;
    logo_url: string;
  }>;
}

export interface TokenItemWithEntity extends TokenItem {
  identity?: TokenEntityDetail;
}

// ---------------------------------------------------------------------------
// Token API
// ---------------------------------------------------------------------------

export interface TokenApi {
  /**
   * Search tokens by query string, optionally scoped to a chain.
   * Maps to: GET /v1/user/search_token?id={address}&q={query}&chain_id={chainId}
   */
  searchToken(
    address: string,
    query: string,
    chainId?: string,
    isAll?: boolean,
  ): Promise<TokenItem[]>;

  /**
   * Search tokens globally (v2 endpoint with entity info).
   * Maps to: GET /v2/token/search?q={query}&chain_id={chainId}
   */
  searchTokensV2(
    query: string,
    chainId?: string,
  ): Promise<TokenItemWithEntity[]>;

  /**
   * Get a single token's details.
   * Maps to: GET /v1/token?id={address}&chain_id={chainId}&token_id={tokenId}
   */
  getToken(
    address: string,
    chainId: string,
    tokenId: string,
  ): Promise<TokenItem>;

  /**
   * Get the user's custom token list (tokens added by UUID).
   * Maps to: POST /v1/user/custom_token_list
   */
  getCustomTokenList(
    uuids: string[],
    address: string,
  ): Promise<TokenItem[]>;

  /**
   * Add a custom token. This is a local-preference operation;
   * the actual list is managed via preference service, but we expose
   * the API helper for querying the token data to validate it exists.
   * Maps to: GET /v1/token?id={address}&chain_id={chainId}&token_id={tokenId}
   */
  addCustomToken(
    address: string,
    chainId: string,
    tokenId: string,
  ): Promise<TokenItem>;

  /**
   * Remove a custom token is a local operation (preference service).
   * This method is a no-op placeholder that resolves immediately.
   */
  removeCustomToken(address: string, tokenId: string): Promise<void>;

  /**
   * Get cached token list for an address.
   * Maps to: GET /v1/user/token_list_cached?id={address}
   */
  getCachedTokenList(address: string): Promise<TokenItem[]>;

  /**
   * Get token entity / detail information.
   * Maps to: GET /v1/token/entity?id={address}&chain_id={chainId}
   */
  getTokenEntity(
    address: string,
    chainId?: string,
  ): Promise<TokenEntityDetail>;
}

export function createTokenApi(client: ApiClient = apiClient): TokenApi {
  return {
    async searchToken(
      address: string,
      query: string,
      chainId?: string,
      isAll?: boolean,
    ): Promise<TokenItem[]> {
      return client.get<TokenItem[]>('/v1/user/search_token', {
        id: address,
        q: query,
        chain_id: chainId,
        is_all: isAll,
      });
    },

    async searchTokensV2(
      query: string,
      chainId?: string,
    ): Promise<TokenItemWithEntity[]> {
      return client.get<TokenItemWithEntity[]>('/v2/token/search', {
        q: query,
        chain_id: chainId,
      });
    },

    async getToken(
      address: string,
      chainId: string,
      tokenId: string,
    ): Promise<TokenItem> {
      return client.get<TokenItem>('/v1/token', {
        id: address,
        chain_id: chainId,
        token_id: tokenId,
      });
    },

    async getCustomTokenList(
      uuids: string[],
      address: string,
    ): Promise<TokenItem[]> {
      return client.post<TokenItem[]>('/v1/user/custom_token_list', {
        uuids,
        id: address,
      });
    },

    async addCustomToken(
      address: string,
      chainId: string,
      tokenId: string,
    ): Promise<TokenItem> {
      // Validate by fetching the token; actual persistence is in PreferenceService
      return client.get<TokenItem>('/v1/token', {
        id: address,
        chain_id: chainId,
        token_id: tokenId,
      });
    },

    async removeCustomToken(
      _address: string,
      _tokenId: string,
    ): Promise<void> {
      // Removal is handled locally via PreferenceService.
      // This is a no-op placeholder for the API layer.
    },

    async getCachedTokenList(address: string): Promise<TokenItem[]> {
      return client.get<TokenItem[]>('/v1/user/token_list_cached', {
        id: address,
      });
    },

    async getTokenEntity(
      address: string,
      chainId?: string,
    ): Promise<TokenEntityDetail> {
      return client.get<TokenEntityDetail>('/v1/token/entity', {
        id: address,
        chain_id: chainId,
      });
    },
  };
}

/** Default singleton token API instance */
export const tokenApi = createTokenApi();
