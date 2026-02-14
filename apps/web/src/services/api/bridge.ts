/**
 * Bridge API Service
 *
 * Wraps Rabby OpenAPI bridge / cross-chain endpoints.
 * Reference: OpenApiService.getBridgeSupportChain, getBridgeAggregatorList,
 *            getBridgeQuoteList, getBridgeQuote, buildBridgeTx, getBridgeHistoryList
 */

import type { ApiClient } from './client';
import { apiClient } from './client';
import type { TokenItem } from './balance';

// ---------------------------------------------------------------------------
// Types (aligned with @rabby-wallet/rabby-api types)
// ---------------------------------------------------------------------------

export interface BridgeItem {
  id: string;
  name: string;
  logo_url: string;
}

export interface BridgeAggregator {
  id: string;
  name: string;
  logo_url: string;
  bridge_list: BridgeItem[];
}

export interface BridgeTokenPair {
  aggregator_id: string;
  from_token: TokenItem;
  to_token: TokenItem;
  from_token_amount: number;
  from_token_raw_amount_hex_str: string;
  from_token_usd_value: number;
}

export interface BridgeQuote {
  aggregator: Omit<BridgeAggregator, 'bridge_list'>;
  bridge_id: string;
  bridge: BridgeItem;
  to_token_amount: number;
  to_token_raw_amount: number;
  to_token_raw_amount_hex_str: string;
  gas_fee: { raw_amount_hex_str: string; usd_value: number };
  protocol_fee: { raw_amount_hex_str: string; usd_value: number };
  rabby_fee: { raw_amount_hex_str: string; usd_value: number };
  duration: number;
  routePath: string;
  approve_contract_id: string;
  tx: {
    chainId: number;
    data: string;
    from: string;
    gasLimit: string;
    gasPrice: string;
    to: string;
    value: string;
  };
  quote_key: Record<string, unknown>;
}

export type BridgeQuoteWithoutTx = Omit<BridgeQuote, 'tx'>;

export interface BridgeHistory {
  aggregator: Omit<BridgeAggregator, 'bridge_list'>;
  bridge: BridgeItem;
  from_token: TokenItem;
  to_token: TokenItem;
  to_actual_token: TokenItem;
  quote: { pay_token_amount: number; receive_token_amount: number };
  actual: { pay_token_amount: number; receive_token_amount: number };
  detail_url: string;
  status: 'pending' | 'completed' | 'failed';
  create_at: number;
  from_tx: { tx_id: string };
  to_tx: { tx_id?: string };
  from_gas: {
    native_token: TokenItem;
    gas_amount: number;
    usd_gas_fee: number;
    gas_price: number;
  };
}

export interface Tx {
  chainId: number;
  data: string;
  from: string;
  gas?: string;
  gasLimit?: string;
  maxFeePerGas?: string;
  maxPriorityFeePerGas?: string;
  gasPrice?: string;
  nonce: string;
  to: string;
  value: string;
}

// ---------------------------------------------------------------------------
// Bridge API
// ---------------------------------------------------------------------------

export interface BridgeApi {
  /**
   * Get list of supported bridge chains.
   * Maps to: GET /v1/bridge/support_chain
   */
  getBridgeSupportedChains(): Promise<string[]>;

  /**
   * Get supported bridge chains (v2).
   * Maps to: GET /v2/bridge/support_chain
   */
  getBridgeSupportedChainsV2(): Promise<string[]>;

  /**
   * Get available bridge aggregators.
   * Maps to: GET /v1/bridge/aggregator_list
   */
  getBridgeAggregatorList(): Promise<BridgeAggregator[]>;

  /**
   * Get bridge quotes from multiple aggregators.
   * Maps to: GET /v1/bridge/quote_list
   */
  getBridgeQuotes(params: {
    aggregator_ids: string;
    user_addr: string;
    from_chain_id: string;
    from_token_id: string;
    from_token_raw_amount: string;
    to_chain_id: string;
    to_token_id: string;
  }): Promise<BridgeQuoteWithoutTx[]>;

  /**
   * Get a single bridge quote with transaction data.
   * Maps to: GET /v1/bridge/quote
   */
  getBridgeQuote(params: {
    aggregator_id: string;
    bridge_id: string;
    user_addr: string;
    from_chain_id: string;
    from_token_id: string;
    from_token_raw_amount: string;
    to_chain_id: string;
    to_token_id: string;
  }): Promise<BridgeQuote>;

  /**
   * Build a bridge transaction for execution.
   * Maps to: POST /v1/bridge/build_tx
   */
  buildBridgeTx(params: {
    aggregator_id: string;
    bridge_id: string;
    user_addr: string;
    from_chain_id: string;
    from_token_id: string;
    from_token_raw_amount: string;
    to_chain_id: string;
    to_token_id: string;
    slippage: string;
    quote_key: string;
  }): Promise<Tx>;

  /**
   * Get bridge transaction history for a user.
   * Maps to: GET /v1/bridge/history_list
   */
  getBridgeHistoryList(params: {
    user_addr: string;
    start: number;
    limit: number;
    is_all?: boolean;
  }): Promise<{
    history_list: BridgeHistory[];
    total_cnt: number;
  }>;

  /**
   * Post a completed bridge history record.
   * Maps to: POST /v1/bridge/history
   */
  postBridgeHistory(params: {
    aggregator_id: string;
    bridge_id: string;
    from_chain_id: string;
    from_token_id: string;
    from_token_amount: string | number;
    to_chain_id: string;
    to_token_id: string;
    to_token_amount: string | number;
    tx_id: string;
    tx: Tx;
    rabby_fee: number;
  }): Promise<{ success: boolean }>;

  /**
   * Get target tokens for bridging to a given chain.
   * Maps to: GET /v2/bridge/to_token_list
   */
  getBridgeToTokenList(params: {
    from_chain_id: string;
    to_chain_id: string;
    from_token_id?: string;
    q?: string;
    user_addr?: string;
  }): Promise<{
    token_list: Array<
      TokenItem & { trade_volume_24h: 'low' | 'middle' | 'high' }
    >;
  }>;
}

export function createBridgeApi(client: ApiClient = apiClient): BridgeApi {
  return {
    async getBridgeSupportedChains(): Promise<string[]> {
      return client.get<string[]>('/v1/bridge/support_chain');
    },

    async getBridgeSupportedChainsV2(): Promise<string[]> {
      return client.get<string[]>('/v2/bridge/support_chain');
    },

    async getBridgeAggregatorList(): Promise<BridgeAggregator[]> {
      return client.get<BridgeAggregator[]>('/v1/bridge/aggregator_list');
    },

    async getBridgeQuotes(params): Promise<BridgeQuoteWithoutTx[]> {
      return client.get<BridgeQuoteWithoutTx[]>('/v1/bridge/quote_list', {
        aggregator_ids: params.aggregator_ids,
        user_addr: params.user_addr,
        from_chain_id: params.from_chain_id,
        from_token_id: params.from_token_id,
        from_token_raw_amount: params.from_token_raw_amount,
        to_chain_id: params.to_chain_id,
        to_token_id: params.to_token_id,
      });
    },

    async getBridgeQuote(params): Promise<BridgeQuote> {
      return client.get<BridgeQuote>('/v1/bridge/quote', {
        aggregator_id: params.aggregator_id,
        bridge_id: params.bridge_id,
        user_addr: params.user_addr,
        from_chain_id: params.from_chain_id,
        from_token_id: params.from_token_id,
        from_token_raw_amount: params.from_token_raw_amount,
        to_chain_id: params.to_chain_id,
        to_token_id: params.to_token_id,
      });
    },

    async buildBridgeTx(params): Promise<Tx> {
      return client.post<Tx>('/v1/bridge/build_tx', params);
    },

    async getBridgeHistoryList(params): Promise<{
      history_list: BridgeHistory[];
      total_cnt: number;
    }> {
      return client.get('/v1/bridge/history_list', {
        user_addr: params.user_addr,
        start: params.start,
        limit: params.limit,
        is_all: params.is_all,
      });
    },

    async postBridgeHistory(params): Promise<{ success: boolean }> {
      return client.post('/v1/bridge/history', params);
    },

    async getBridgeToTokenList(params): Promise<{
      token_list: Array<
        TokenItem & { trade_volume_24h: 'low' | 'middle' | 'high' }
      >;
    }> {
      return client.get('/v2/bridge/to_token_list', {
        from_chain_id: params.from_chain_id,
        to_chain_id: params.to_chain_id,
        from_token_id: params.from_token_id,
        q: params.q,
        user_addr: params.user_addr,
      });
    },
  };
}

/** Default singleton bridge API instance */
export const bridgeApi = createBridgeApi();
