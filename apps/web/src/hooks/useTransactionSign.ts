import { useState, useCallback } from 'react';
import type { TransactionRequest } from '@rabby/shared';
import { useWallet } from '../contexts/WalletContext';

export function useTransactionSign() {
  const { wcProvider } = useWallet();
  const [signing, setSigning] = useState(false);
  const [txHash, setTxHash] = useState<string | null>(null);
  const [error, setError] = useState<Error | null>(null);

  const sign = useCallback(
    async (tx: TransactionRequest): Promise<string> => {
      if (!wcProvider) {
        throw new Error('WalletConnect provider not available');
      }
      setSigning(true);
      setError(null);
      setTxHash(null);
      try {
        const hash = await wcProvider.request({
          method: 'eth_sendTransaction',
          params: [tx],
        });
        setTxHash(hash as string);
        setSigning(false);
        return hash as string;
      } catch (err) {
        const e = err instanceof Error ? err : new Error(String(err));
        setError(e);
        setSigning(false);
        throw e;
      }
    },
    [wcProvider],
  );

  return { signing, txHash, error, sign };
}
