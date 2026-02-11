import type { SwapQuote } from '@rabby/shared';
import { apiGet, apiPost } from '../client';

export interface SwapQuoteParams {
  fromToken: string;
  toToken: string;
  amount: string;
  chainId?: string;
  slippage?: string;
  dexId?: string;
}

export function getSwapQuote(params: SwapQuoteParams) {
  return apiGet<SwapQuote[]>('/api/swap/quote', { ...params });
}

export function postSwap(params: {
  dex_id: string;
  from_token: string;
  to_token: string;
  amount: string;
  chain_id: string;
  slippage: string;
  from_address: string;
}) {
  return apiPost<SwapQuote>('/api/swap/build', params);
}
