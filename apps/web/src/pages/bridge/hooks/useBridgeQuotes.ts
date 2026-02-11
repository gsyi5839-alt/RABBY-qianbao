import { useState, useEffect, useRef } from 'react';
import type { BridgeQuote, TokenItem } from '@rabby/shared';
import { getBridgeQuotes } from '../../../services/api/bridge';
import { useDebounce } from '../../../hooks/useDebounce';

export function useBridgeQuotes(
  fromChain: string | undefined,
  toChain: string | undefined,
  fromToken: TokenItem | null,
  toToken: TokenItem | null,
  amount: string,
  fromAddress: string | undefined,
) {
  const [quotes, setQuotes] = useState<BridgeQuote[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  const mountedRef = useRef(true);

  const debouncedAmount = useDebounce(amount, 500);

  useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
    };
  }, []);

  useEffect(() => {
    if (!fromChain || !toChain || !fromToken || !debouncedAmount || Number(debouncedAmount) <= 0 || !fromAddress) {
      setQuotes([]);
      setError(null);
      return;
    }

    setLoading(true);
    setError(null);

    getBridgeQuotes({
      fromChain,
      toChain,
      fromToken: fromToken.id,
      toToken: toToken?.id || fromToken.id,
      amount: debouncedAmount,
      fromAddress,
    })
      .then((result) => {
        if (mountedRef.current) {
          setQuotes(result);
          setLoading(false);
        }
      })
      .catch((err) => {
        if (mountedRef.current) {
          setError(err instanceof Error ? err : new Error(String(err)));
          setQuotes([]);
          setLoading(false);
        }
      });
  }, [fromChain, toChain, fromToken, toToken, debouncedAmount, fromAddress]);

  return { quotes, loading, error };
}
