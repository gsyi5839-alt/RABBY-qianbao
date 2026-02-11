import React, { createContext, useContext, useState, useCallback, useEffect, useRef } from 'react';
import type { TokenItem } from '@rabby/shared';
import { getTokenList } from '../services/api/tokens';
import { useWallet } from './WalletContext';

interface TokenContextValue {
  tokens: TokenItem[];
  loading: boolean;
  refresh: () => void;
}

const TokenContext = createContext<TokenContextValue | null>(null);

export function TokenProvider({ children }: { children: React.ReactNode }) {
  const { currentAccount } = useWallet();
  const address = currentAccount?.address;
  const [tokens, setTokens] = useState<TokenItem[]>([]);
  const [loading, setLoading] = useState(false);
  const mountedRef = useRef(true);

  const fetchTokens = useCallback(() => {
    if (!address) {
      setTokens([]);
      return;
    }
    setLoading(true);
    getTokenList(address)
      .then((res) => {
        if (mountedRef.current) {
          setTokens(res.tokens);
        }
      })
      .catch(() => {})
      .finally(() => {
        if (mountedRef.current) setLoading(false);
      });
  }, [address]);

  useEffect(() => {
    mountedRef.current = true;
    fetchTokens();
    return () => {
      mountedRef.current = false;
    };
  }, [fetchTokens]);

  return (
    <TokenContext.Provider value={{ tokens, loading, refresh: fetchTokens }}>
      {children}
    </TokenContext.Provider>
  );
}

export function useTokenContext() {
  const ctx = useContext(TokenContext);
  if (!ctx) throw new Error('useTokenContext must be used within TokenProvider');
  return ctx;
}
