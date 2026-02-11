import { useState, useEffect, useRef } from 'react';
import type { SwapQuote, TokenItem } from '@rabby/shared';
import { getSwapQuote } from '../../../services/api/swap';
import { useDebounce } from '../../../hooks/useDebounce';

export function useSwapQuotes(
  fromToken: TokenItem | null,
  toToken: TokenItem | null,
  amount: string,
  chainId: string | undefined,
  slippage: number,
) {
  const [quotes, setQuotes] = useState<SwapQuote[]>([]);
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
    if (!fromToken || !toToken || !debouncedAmount || Number(debouncedAmount) <= 0) {
      setQuotes([]);
      setError(null);
      return;
    }

    setLoading(true);
    setError(null);

    getSwapQuote({
      fromToken: fromToken.id,
      toToken: toToken.id,
      amount: debouncedAmount,
      chainId,
      slippage: String(slippage),
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
  }, [fromToken, toToken, debouncedAmount, chainId, slippage]);

  return { quotes, loading, error };
}
