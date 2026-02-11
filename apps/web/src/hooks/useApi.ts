import { useState, useEffect, useCallback, useRef } from 'react';

export function useApi<T>(
  fetcher: () => Promise<T>,
  deps: unknown[],
): { data: T | null; loading: boolean; error: Error | null; refresh: () => void } {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);
  const mountedRef = useRef(true);

  const doFetch = useCallback(() => {
    setLoading(true);
    setError(null);
    fetcher()
      .then((result) => {
        if (mountedRef.current) {
          setData(result);
          setLoading(false);
        }
      })
      .catch((err) => {
        if (mountedRef.current) {
          setError(err instanceof Error ? err : new Error(String(err)));
          setLoading(false);
        }
      });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);

  useEffect(() => {
    mountedRef.current = true;
    doFetch();
    return () => {
      mountedRef.current = false;
    };
  }, [doFetch]);

  const refresh = useCallback(() => {
    doFetch();
  }, [doFetch]);

  return { data, loading, error, refresh };
}
