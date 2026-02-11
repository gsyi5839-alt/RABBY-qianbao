import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import type { Chain } from '@rabby/shared';
import { getChainsList } from '../services/api/chains';

const STORAGE_KEY = 'rabby_current_chain';

interface ChainContextValue {
  chains: Chain[];
  currentChain: Chain | null;
  setCurrentChain: (chain: Chain) => void;
  loading: boolean;
}

const ChainContext = createContext<ChainContextValue | null>(null);

export function ChainProvider({ children }: { children: React.ReactNode }) {
  const [chains, setChains] = useState<Chain[]>([]);
  const [currentChain, setCurrentChainState] = useState<Chain | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    getChainsList()
      .then((list) => {
        setChains(list);
        // Restore persisted chain
        try {
          const saved = localStorage.getItem(STORAGE_KEY);
          if (saved) {
            const parsed = JSON.parse(saved) as Chain;
            const found = list.find((c) => c.id === parsed.id);
            if (found) {
              setCurrentChainState(found);
              setLoading(false);
              return;
            }
          }
        } catch {}
        // Default to first chain (usually Ethereum)
        if (list.length > 0) {
          setCurrentChainState(list[0]);
        }
        setLoading(false);
      })
      .catch(() => {
        setLoading(false);
      });
  }, []);

  const setCurrentChain = useCallback((chain: Chain) => {
    setCurrentChainState(chain);
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(chain));
    } catch {}
  }, []);

  return (
    <ChainContext.Provider value={{ chains, currentChain, setCurrentChain, loading }}>
      {children}
    </ChainContext.Provider>
  );
}

export function useChainContext() {
  const ctx = useContext(ChainContext);
  if (!ctx) throw new Error('useChainContext must be used within ChainProvider');
  return ctx;
}
