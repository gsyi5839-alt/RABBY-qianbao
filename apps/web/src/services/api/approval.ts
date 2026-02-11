import type { TokenApproval } from '@rabby/shared';
import { apiGet } from '../client';

export function getTokenApprovals(address: string) {
  return apiGet<TokenApproval[]>(`/api/approval/${address}`);
}
