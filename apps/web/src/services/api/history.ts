import type { TxHistoryItem } from '@rabby/shared';
import { apiGet } from '../client';

export interface TxHistoryResponse {
  history_list: TxHistoryItem[];
  total: number;
}

export function getTxHistory(
  address: string,
  params?: { chain?: string; page?: number; limit?: number },
) {
  return apiGet<TxHistoryResponse>(`/api/history/${address}`, params);
}
