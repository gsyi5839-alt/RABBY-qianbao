import type { NFTCollection } from '@rabby/shared';
import { apiGet } from '../client';

export function getNFTCollections(address: string) {
  return apiGet<NFTCollection[]>(`/api/nft/${address}`);
}
