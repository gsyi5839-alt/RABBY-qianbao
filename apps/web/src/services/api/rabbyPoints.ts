import type { RabbyPointsInfo } from '@rabby/shared';
import { apiGet } from '../client';

export function getUserPoints(address: string) {
  return apiGet<RabbyPointsInfo>(`/api/points/${address}`);
}

export function getCampaigns() {
  return apiGet<RabbyPointsInfo['campaigns']>('/api/points/campaigns');
}
