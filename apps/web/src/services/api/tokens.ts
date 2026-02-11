import type { TokenItem } from '@rabby/shared';
import { apiGet } from '../client';

export interface TokenListResponse {
  tokens: TokenItem[];
}

export function getTokenList(address: string, chain?: string) {
  return apiGet<TokenListResponse>(`/api/tokens/${address}`, { chain });
}
