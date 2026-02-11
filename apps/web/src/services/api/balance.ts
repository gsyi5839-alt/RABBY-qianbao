import { apiGet } from '../client';

export interface BalanceResponse {
  total_usd_value: number;
  chain_list: Array<{
    id: string;
    community_id: number;
    name: string;
    logo_url: string;
    usd_value: number;
  }>;
}

export function getTotalBalance(address: string) {
  return apiGet<BalanceResponse>(`/api/balance/${address}`);
}
