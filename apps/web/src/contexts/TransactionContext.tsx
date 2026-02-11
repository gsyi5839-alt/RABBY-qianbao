import React, { createContext, useContext, useState, useCallback } from 'react';
import type { TransactionRequest } from '@rabby/shared';

interface PendingTx {
  hash: string;
  tx: TransactionRequest;
  timestamp: number;
  status: 'pending' | 'confirmed' | 'failed';
}

interface TransactionContextValue {
  pendingTxs: PendingTx[];
  addPendingTx: (hash: string, tx: TransactionRequest) => void;
  removePendingTx: (hash: string) => void;
  clearPendingTxs: () => void;
}

const TransactionContext = createContext<TransactionContextValue | null>(null);

export function TransactionProvider({ children }: { children: React.ReactNode }) {
  const [pendingTxs, setPendingTxs] = useState<PendingTx[]>([]);

  const addPendingTx = useCallback((hash: string, tx: TransactionRequest) => {
    setPendingTxs((prev) => [
      ...prev,
      { hash, tx, timestamp: Date.now(), status: 'pending' },
    ]);
  }, []);

  const removePendingTx = useCallback((hash: string) => {
    setPendingTxs((prev) => prev.filter((t) => t.hash !== hash));
  }, []);

  const clearPendingTxs = useCallback(() => {
    setPendingTxs([]);
  }, []);

  return (
    <TransactionContext.Provider value={{ pendingTxs, addPendingTx, removePendingTx, clearPendingTxs }}>
      {children}
    </TransactionContext.Provider>
  );
}

export function useTransactionContext() {
  const ctx = useContext(TransactionContext);
  if (!ctx) throw new Error('useTransactionContext must be used within TransactionProvider');
  return ctx;
}
