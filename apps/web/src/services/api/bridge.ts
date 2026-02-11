import type { BridgeQuote } from '@rabby/shared';
import { apiGet, apiPost } from '../client';

export interface BridgeQuoteParams {
  fromChain: string;
  toChain: string;
  fromToken: string;
  toToken: string;
  amount: string;
  fromAddress: string;
}

export function getBridgeQuotes(params: BridgeQuoteParams) {
  return apiGet<BridgeQuote[]>('/api/bridge/quotes', { ...params });
}

export function buildBridgeTx(params: {
  bridge_id: string;
  from_chain_id: string;
  to_chain_id: string;
  from_token: string;
  to_token: string;
  amount: string;
  from_address: string;
}) {
  return apiPost<BridgeQuote>('/api/bridge/build', params);
}
