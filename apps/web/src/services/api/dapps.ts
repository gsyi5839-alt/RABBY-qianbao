import { apiGet } from '../client';

export interface DappItem {
  id: string;
  name: string;
  url: string;
  icon?: string;
  category?: string;
}

export interface DappListResponse {
  list: DappItem[];
}

export function getDappsList(query?: string) {
  return apiGet<DappListResponse>('/api/dapps/list', query ? { q: query } : undefined);
}
