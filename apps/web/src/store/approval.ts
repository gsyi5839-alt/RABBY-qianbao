import { create } from 'zustand';

/**
 * Approval request types for web wallet interactions.
 * Maps to the extension's approval popup flow.
 */
export type ApprovalType =
  | 'SignTx'
  | 'SignText'
  | 'SignTypedData'
  | 'AddChain'
  | 'SwitchChain'
  | 'AddToken'
  | 'Connect';

export interface ApprovalRequest {
  id: string;
  type: ApprovalType;
  origin?: string;
  icon?: string;
  data: Record<string, unknown>;
  createdAt: number;
}

export interface ApprovalStore {
  // State
  currentApproval: ApprovalRequest | null;
  approvalQueue: ApprovalRequest[];

  // Actions
  setCurrentApproval: (approval: ApprovalRequest | null) => void;
  addToQueue: (approval: ApprovalRequest) => void;
  removeFromQueue: (approvalId: string) => void;
  approve: () => Promise<void>;
  reject: () => void;
  processNext: () => void;
  reset: () => void;
}

const initialState = {
  currentApproval: null as ApprovalRequest | null,
  approvalQueue: [] as ApprovalRequest[],
};

export const useApprovalStore = create<ApprovalStore>()((set, get) => ({
  ...initialState,

  setCurrentApproval: (approval) => {
    set({ currentApproval: approval });
  },

  addToQueue: (approval) => {
    const { approvalQueue, currentApproval } = get();
    if (!currentApproval) {
      // No current approval, set it directly
      set({ currentApproval: approval });
    } else {
      // Queue it behind the current one
      set({ approvalQueue: [...approvalQueue, approval] });
    }
  },

  removeFromQueue: (approvalId) => {
    const { approvalQueue } = get();
    set({
      approvalQueue: approvalQueue.filter((a) => a.id !== approvalId),
    });
  },

  approve: async () => {
    const { currentApproval } = get();
    if (!currentApproval) return;

    try {
      // TODO: Call approval service when available
      // await approvalService.approve(currentApproval.id, currentApproval.data);
    } catch (error) {
      console.error('[ApprovalStore] approve error:', error);
      throw error;
    } finally {
      // Move to next approval in queue
      get().processNext();
    }
  },

  reject: () => {
    const { currentApproval } = get();
    if (!currentApproval) return;

    // TODO: Call approval service rejection when available
    // approvalService.reject(currentApproval.id);

    // Move to next approval in queue
    get().processNext();
  },

  processNext: () => {
    const { approvalQueue } = get();
    if (approvalQueue.length > 0) {
      const [next, ...rest] = approvalQueue;
      set({ currentApproval: next, approvalQueue: rest });
    } else {
      set({ currentApproval: null });
    }
  },

  reset: () => {
    set(initialState);
  },
}));
