import { create } from 'zustand';
import type { TransactionRequest } from '@rabby/shared';

/**
 * Pending transaction representation for the web app.
 * Extends the base TransactionRequest with tracking metadata.
 */
export interface TransactionPending {
  id: string;
  hash?: string;
  from: string;
  to: string;
  value?: string;
  data?: string;
  chainId?: number;
  nonce?: number;
  gasUsed?: string;
  status: 'pending' | 'confirmed' | 'failed' | 'dropped';
  createdAt: number;
  /** Raw tx request for re-submission / speed-up */
  rawTx?: TransactionRequest;
}

export interface TransactionStore {
  // State
  pendingTxs: TransactionPending[];
  pendingApprovalCount: number;
  recentTxIds: string[];

  // Actions
  addPendingTx: (tx: TransactionPending) => void;
  removePendingTx: (txId: string) => void;
  updatePendingTx: (
    txId: string,
    updates: Partial<TransactionPending>
  ) => void;
  clearPendingTxs: () => void;
  setPendingApprovalCount: (count: number) => void;
  fetchPendingCount: (address: string) => Promise<void>;
  reset: () => void;
}

const initialState = {
  pendingTxs: [] as TransactionPending[],
  pendingApprovalCount: 0,
  recentTxIds: [] as string[],
};

export const useTransactionStore = create<TransactionStore>()((set, get) => ({
  ...initialState,

  addPendingTx: (tx) => {
    const { pendingTxs, recentTxIds } = get();
    const exists = pendingTxs.some((t) => t.id === tx.id);
    if (!exists) {
      set({
        pendingTxs: [tx, ...pendingTxs],
        recentTxIds: [tx.id, ...recentTxIds].slice(0, 50),
      });
    }
  },

  removePendingTx: (txId) => {
    const { pendingTxs } = get();
    set({ pendingTxs: pendingTxs.filter((tx) => tx.id !== txId) });
  },

  updatePendingTx: (txId, updates) => {
    const { pendingTxs } = get();
    set({
      pendingTxs: pendingTxs.map((tx) =>
        tx.id === txId ? { ...tx, ...updates } : tx
      ),
    });
  },

  clearPendingTxs: () => {
    set({ pendingTxs: [] });
  },

  setPendingApprovalCount: (count) => {
    set({ pendingApprovalCount: count });
  },

  fetchPendingCount: async (address: string) => {
    if (!address) return;
    try {
      // TODO: Call wallet API to get pending count when available
      // const count = await walletApi.getPendingCount(address);
      // set({ pendingApprovalCount: count });
    } catch (error) {
      console.error('[TransactionStore] fetchPendingCount error:', error);
    }
  },

  reset: () => {
    set(initialState);
  },
}));
