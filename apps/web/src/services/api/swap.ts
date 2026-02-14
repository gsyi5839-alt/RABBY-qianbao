/**
 * Swap API Service
 *
 * Wraps Rabby OpenAPI swap-related endpoints.
 * Reference: OpenApiService.getSwapQuote, getDEXList, postSwap,
 *            getSwapTokenList, checkSlippage, getSwapTradeList
 */

import type { ApiClient } from './client';
import { apiClient } from './client';
import type { TokenItem } from './balance';

// ---------------------------------------------------------------------------
// Types (aligned with @rabby-wallet/rabby-api types)
// ---------------------------------------------------------------------------

export interface SwapQuoteParams {
  /** User address */
  id: string;
  /** Chain server ID (e.g. "eth") */
  chain_id: string;
  /** DEX identifier */
  dex_id: string;
  /** Pay token ID */
  pay_token_id: string;
  /** Raw amount of pay token (in minimal unit as string) */
  pay_token_raw_amount: string;
  /** Receive token ID */
  receive_token_id: string;
  /** Slippage tolerance (e.g. "0.01" for 1%) */
  slippage?: string | number;
  /** Whether to include Rabby fee */
  fee?: boolean;
}

export interface SwapQuoteResult {
  receive_token_raw_amount: number;
  dex_approve_to: string;
  dex_swap_to: string;
  dex_swap_calldata: string;
  is_wrapped: boolean;
  gas: {
    gas_used: number;
    gas_price: number;
    gas_cost_value: number;
    gas_cost_usd_value: number;
  };
  pay_token: TokenItem;
  receive_token: TokenItem;
  dex_fee_desc?: string | null;
}

export interface DexInfo {
  id: string;
  name: string;
  logo_url: string;
  site_url: string;
  type: string;
}

export interface SlippageStatus {
  is_valid: boolean;
  suggest_slippage: number;
}

export interface SwapItem {
  chain: string;
  tx_id: string;
  create_at: number;
  finished_at: number;
  status: 'Pending' | 'Completed' | 'Finished';
  dex_id: string;
  pay_token: TokenItem;
  receive_token: TokenItem;
  gas: {
    native_token: TokenItem;
    native_gas_fee: number;
    usd_gas_fee: number;
    gas_price: number;
  };
  quote: {
    pay_token_amount: number;
    receive_token_amount: number;
    slippage: number;
  };
  actual: {
    pay_token_amount: number;
    receive_token_amount: number;
    slippage: number;
  };
}

export interface SwapTradeList {
  history_list: SwapItem[];
  total_cnt: number;
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
// Swap API
// ---------------------------------------------------------------------------

export interface SwapApi {
  /**
   * Get swap quote from a specific DEX.
   * Maps to: GET /v1/swap/quote
   */
  getSwapQuote(params: SwapQuoteParams): Promise<SwapQuoteResult>;

  /**
   * Get list of supported DEXes on a chain.
   * Maps to: GET /v1/swap/dex_list?chain_id={chainId}
   */
  getSwapSupportedDexes(chainId: string): Promise<DexInfo[]>;

  /**
   * Get the list of all supported DEX IDs.
   * Maps to: GET /v1/swap/supported_dex_list
   */
  getSupportedDEXList(): Promise<{ dex_list: string[] }>;

  /**
   * Submit swap transaction data for tracking.
   * Maps to: POST /v1/swap
   */
  postSwap(params: {
    quote: {
      pay_token_id: string;
      pay_token_amount: number;
      receive_token_id: string;
      receive_token_amount: number;
      slippage: number;
    };
    dex_id: string;
    tx_id: string;
    tx: Tx;
  }): Promise<unknown>;

  /**
   * Get tokens available for swap on a specific chain.
   * Maps to: GET /v1/swap/token_list?id={address}&chain_id={chainId}
   */
  getSwapTokenList(address: string, chainId?: string): Promise<TokenItem[]>;

  /**
   * Check if a slippage value is acceptable.
   * Maps to: GET /v1/swap/check_slippage
   */
  checkSlippage(params: {
    chain_id: string;
    slippage: string;
    from_token_id: string;
    to_token_id: string;
  }): Promise<SlippageStatus>;

  /**
   * Get suggested slippage for a swap pair.
   * Maps to: GET /v1/swap/suggest_slippage
   */
  suggestSlippage(params: {
    chain_id: string;
    slippage: string;
    from_token_id: string;
    to_token_id: string;
    from_token_amount: string;
  }): Promise<{ suggest_slippage: number }>;

  /**
   * Get swap trade history for a user.
   * Maps to: GET /v1/swap/trade_list?user_addr={address}&start={start}&limit={limit}
   */
  getSwapTradeList(params: {
    user_addr: string;
    start: string;
    limit: string;
  }): Promise<SwapTradeList>;
}

export function createSwapApi(client: ApiClient = apiClient): SwapApi {
  return {
    async getSwapQuote(params: SwapQuoteParams): Promise<SwapQuoteResult> {
      return client.get<SwapQuoteResult>('/v1/swap/quote', {
        id: params.id,
        chain_id: params.chain_id,
        dex_id: params.dex_id,
        pay_token_id: params.pay_token_id,
        pay_token_raw_amount: params.pay_token_raw_amount,
        receive_token_id: params.receive_token_id,
        slippage: params.slippage,
        fee: params.fee,
      });
    },

    async getSwapSupportedDexes(chainId: string): Promise<DexInfo[]> {
      return client.get<DexInfo[]>('/v1/swap/dex_list', {
        chain_id: chainId,
      });
    },

    async getSupportedDEXList(): Promise<{ dex_list: string[] }> {
      return client.get('/v1/swap/supported_dex_list');
    },

    async postSwap(params: {
      quote: {
        pay_token_id: string;
        pay_token_amount: number;
        receive_token_id: string;
        receive_token_amount: number;
        slippage: number;
      };
      dex_id: string;
      tx_id: string;
      tx: Tx;
    }): Promise<unknown> {
      return client.post('/v1/swap', params);
    },

    async getSwapTokenList(
      address: string,
      chainId?: string,
    ): Promise<TokenItem[]> {
      return client.get<TokenItem[]>('/v1/swap/token_list', {
        id: address,
        chain_id: chainId,
      });
    },

    async checkSlippage(params: {
      chain_id: string;
      slippage: string;
      from_token_id: string;
      to_token_id: string;
    }): Promise<SlippageStatus> {
      return client.get<SlippageStatus>('/v1/swap/check_slippage', params);
    },

    async suggestSlippage(params: {
      chain_id: string;
      slippage: string;
      from_token_id: string;
      to_token_id: string;
      from_token_amount: string;
    }): Promise<{ suggest_slippage: number }> {
      return client.get('/v1/swap/suggest_slippage', params);
    },

    async getSwapTradeList(params: {
      user_addr: string;
      start: string;
      limit: string;
    }): Promise<SwapTradeList> {
      return client.get<SwapTradeList>('/v1/swap/trade_list', params);
    },
  };
}

/** Default singleton swap API instance */
export const swapApi = createSwapApi();
