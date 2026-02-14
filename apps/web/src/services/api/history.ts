/**
 * History API Service
 *
 * Wraps Rabby OpenAPI transaction history endpoints.
 * Reference: OpenApiService.listTxHisotry, getAllTxHistory, getPendingCount
 */

import type { ApiClient } from './client';
import { apiClient } from './client';
import type { TokenItem } from './balance';

// ---------------------------------------------------------------------------
// Types (aligned with @rabby-wallet/rabby-api types)
// ---------------------------------------------------------------------------

export interface TxHistoryItem {
  cate_id: string | null;
  chain: string;
  debt_liquidated: null;
  id: string;
  is_scam: boolean;
  other_addr: string;
  project_id: null | string;
  receives: Array<{
    amount: number;
    from_addr: string;
    token_id: string;
    price?: number;
  }>;
  sends: Array<{
    amount: number;
    to_addr: string;
    token_id: string;
    price?: number;
  }>;
  time_at: number;
  token_approve: {
    spender: string;
    token_id: string;
    value: number;
    price?: number;
  } | null;
  tx: {
    eth_gas_fee: number;
    from_addr: string;
    name: string;
    params: unknown[];
    status: number;
    to_addr: string;
    usd_gas_fee: number;
    value: number;
    message: string | null;
  } | null;
}

export interface TxHistoryResult {
  cate_dict: Record<string, { id: string; name: string }>;
  history_list: TxHistoryItem[];
  project_dict: Record<
    string,
    { chain: string; id: string; logo_url: string; name: string }
  >;
  token_dict: Record<string, TokenItem>;
}

export interface TxAllHistoryResult
  extends Omit<TxHistoryResult, 'token_dict'> {
  token_uuid_dict: Record<string, TokenItem>;
  project_dict: TxHistoryResult['project_dict'];
}

export interface ChainWithPendingCount {
  id: string;
  community_id: number;
  name: string;
  native_token_id: string;
  logo_url: string;
  wrapped_token_id: string;
  symbol: string;
  is_support_history: boolean;
  born_at: number | null;
  pending_tx_count: number;
}

// ---------------------------------------------------------------------------
// History API
// ---------------------------------------------------------------------------

export interface HistoryApi {
  /**
   * Get transaction history for an address, optionally filtered by chain.
   * Maps to: GET /v1/user/history_list?id={address}&chain_id={chainId}
   */
  getTxHistory(
    address: string,
    chainId?: string,
    startTime?: number,
    pageCount?: number,
  ): Promise<TxHistoryResult>;

  /**
   * Get full transaction history across all chains (async job).
   * Maps to: GET /v1/user/all_history_list?id={address}
   */
  getAllTxHistory(
    address: string,
    startTime?: number,
    pageCount?: number,
  ): Promise<TxAllHistoryResult>;

  /**
   * Get the pending transaction count for an address.
   * Maps to: GET /v1/wallet/pending_count?user_addr={address}
   */
  getPendingTxCount(address: string): Promise<{
    total_count: number;
    chains: ChainWithPendingCount[];
  }>;

  /**
   * Check if a user has new transactions since a given timestamp.
   * Maps to: GET /v1/user/has_new_tx_from?address={address}&start_time={startTime}
   */
  hasNewTxFrom(
    address: string,
    startTime: number,
  ): Promise<{ has_new_tx: boolean }>;

  /**
   * Get transaction history filtered by token.
   * Maps to: GET /v1/user/history_list?id={address}&token_id={tokenId}
   */
  getTxHistoryByToken(
    address: string,
    tokenId: string,
    chainId?: string,
    startTime?: number,
    pageCount?: number,
  ): Promise<TxHistoryResult>;
}

export function createHistoryApi(client: ApiClient = apiClient): HistoryApi {
  return {
    async getTxHistory(
      address: string,
      chainId?: string,
      startTime?: number,
      pageCount?: number,
    ): Promise<TxHistoryResult> {
      return client.get<TxHistoryResult>('/v1/user/history_list', {
        id: address,
        chain_id: chainId,
        start_time: startTime,
        page_count: pageCount,
      });
    },

    async getAllTxHistory(
      address: string,
      startTime?: number,
      pageCount?: number,
    ): Promise<TxAllHistoryResult> {
      return client.get<TxAllHistoryResult>('/v1/user/all_history_list', {
        id: address,
        start_time: startTime,
        page_count: pageCount,
      });
    },

    async getPendingTxCount(address: string): Promise<{
      total_count: number;
      chains: ChainWithPendingCount[];
    }> {
      return client.get('/v1/wallet/pending_count', {
        user_addr: address,
      });
    },

    async hasNewTxFrom(
      address: string,
      startTime: number,
    ): Promise<{ has_new_tx: boolean }> {
      return client.get('/v1/user/has_new_tx_from', {
        address,
        start_time: startTime,
      });
    },

    async getTxHistoryByToken(
      address: string,
      tokenId: string,
      chainId?: string,
      startTime?: number,
      pageCount?: number,
    ): Promise<TxHistoryResult> {
      return client.get<TxHistoryResult>('/v1/user/history_list', {
        id: address,
        token_id: tokenId,
        chain_id: chainId,
        start_time: startTime,
        page_count: pageCount,
      });
    },
  };
}

/** Default singleton history API instance */
export const historyApi = createHistoryApi();
