import type { Chain } from '@rabby/shared';
import { apiGet } from '../client';

export function getChainsList() {
  return apiGet<Chain[]>('/api/chains/list');
}
