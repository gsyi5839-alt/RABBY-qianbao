import { useState, useCallback } from 'react';
import type { TokenApproval, TransactionRequest } from '@rabby/shared';
import { useWallet } from '../../../contexts/WalletContext';

// ERC20 approve(address,uint256) function selector
const APPROVE_SELECTOR = '0x095ea7b3';

function encodeApproveZero(spenderAddress: string): string {
  // approve(spender, 0) - set allowance to zero
  const spender = spenderAddress.replace('0x', '').padStart(64, '0');
  const amount = '0'.padStart(64, '0');
  return `${APPROVE_SELECTOR}${spender}${amount}`;
}

export function useRevokeApproval() {
  const { currentAccount, sendTransaction } = useWallet();
  const [revoking, setRevoking] = useState<string | null>(null);
  const [error, setError] = useState<Error | null>(null);

  const revoke = useCallback(
    async (approval: TokenApproval) => {
      if (!currentAccount) {
        throw new Error('No account connected');
      }

      setRevoking(approval.id);
      setError(null);

      try {
        const tx: TransactionRequest = {
          from: currentAccount.address,
          to: approval.token.id,
          data: encodeApproveZero(approval.spender.id),
        };

        const hash = await sendTransaction(tx);
        return hash;
      } catch (err) {
        const e = err instanceof Error ? err : new Error(String(err));
        setError(e);
        throw e;
      } finally {
        setRevoking(null);
      }
    },
    [currentAccount, sendTransaction],
  );

  return { revoke, revoking, error };
}
