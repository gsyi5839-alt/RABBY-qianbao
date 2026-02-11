import React, { createContext, useContext, useState, useCallback, useEffect, useRef } from 'react';
import { getTotalBalance, type BalanceResponse } from '../services/api/balance';
import { useWallet } from './WalletContext';

interface BalanceContextValue {
  totalBalance: number;
  chainBalances: BalanceResponse['chain_list'];
  loading: boolean;
  refresh: () => void;
}

const BalanceContext = createContext<BalanceContextValue | null>(null);

const REFRESH_INTERVAL = 30_000;

export function BalanceProvider({ children }: { children: React.ReactNode }) {
  const { currentAccount } = useWallet();
  const address = currentAccount?.address;
  const [totalBalance, setTotalBalance] = useState(0);
  const [chainBalances, setChainBalances] = useState<BalanceResponse['chain_list']>([]);
  const [loading, setLoading] = useState(false);
  const mountedRef = useRef(true);

  const fetchBalance = useCallback(() => {
    if (!address) {
      setTotalBalance(0);
      setChainBalances([]);
      return;
    }
    setLoading(true);
    getTotalBalance(address)
      .then((res) => {
        if (mountedRef.current) {
          setTotalBalance(res.total_usd_value);
          setChainBalances(res.chain_list);
        }
      })
      .catch(() => {})
      .finally(() => {
        if (mountedRef.current) setLoading(false);
      });
  }, [address]);

  useEffect(() => {
    mountedRef.current = true;
    fetchBalance();
    const id = setInterval(fetchBalance, REFRESH_INTERVAL);
    return () => {
      mountedRef.current = false;
      clearInterval(id);
    };
  }, [fetchBalance]);

  return (
    <BalanceContext.Provider value={{ totalBalance, chainBalances, loading, refresh: fetchBalance }}>
      {children}
    </BalanceContext.Provider>
  );
}

export function useBalanceContext() {
  const ctx = useContext(BalanceContext);
  if (!ctx) throw new Error('useBalanceContext must be used within BalanceProvider');
  return ctx;
}
