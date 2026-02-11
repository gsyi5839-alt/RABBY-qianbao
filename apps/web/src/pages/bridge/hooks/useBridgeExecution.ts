import { useState, useCallback } from 'react';
import type { BridgeQuote } from '@rabby/shared';
import { buildBridgeTx } from '../../../services/api/bridge';
import { useWallet } from '../../../contexts/WalletContext';

export function useBridgeExecution() {
  const { currentAccount, sendTransaction } = useWallet();
  const [executing, setExecuting] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const executeBridge = useCallback(
    async (quote: BridgeQuote, amount: string) => {
      if (!currentAccount) {
        throw new Error('No account connected');
      }

      setExecuting(true);
      setError(null);

      try {
        const built = await buildBridgeTx({
          bridge_id: quote.bridge_id,
          from_chain_id: quote.from_chain_id,
          to_chain_id: quote.to_chain_id,
          from_token: quote.from_token.id,
          to_token: quote.to_token.id,
          amount,
          from_address: currentAccount.address,
        });

        if (!built.tx) {
          throw new Error('Failed to build bridge transaction');
        }

        const hash = await sendTransaction(built.tx);
        return hash;
      } catch (err) {
        const e = err instanceof Error ? err : new Error(String(err));
        setError(e);
        throw e;
      } finally {
        setExecuting(false);
      }
    },
    [currentAccount, sendTransaction],
  );

  return { executeBridge, executing, error };
}
