import type { GasAccountInfo } from '@rabby/shared';
import { apiGet } from '../client';

export interface GasHistoryItem {
  id: string;
  type: 'deposit' | 'withdraw' | 'gas_fee';
  amount: number;
  chain: string;
  timestamp: number;
  status: 'success' | 'pending' | 'failed';
}

export function getGasAccountInfo(address: string) {
  return apiGet<GasAccountInfo>(`/api/gas-account/${address}`);
}

export function getGasAccountHistory(address: string) {
  return apiGet<GasHistoryItem[]>('/api/gas-account/history', { address });
}
