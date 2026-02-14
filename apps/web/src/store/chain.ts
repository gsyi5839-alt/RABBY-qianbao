import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { Chain } from '@rabby/shared';

export interface ChainStore {
  // State
  currentChain: string;
  chainList: Chain[];
  pinnedChains: string[];
  customRPCs: Record<string, string>;
  matteredChainBalances: Record<string, { usdValue: number }>;

  // Actions
  setCurrentChain: (chain: string) => void;
  setChainList: (chains: Chain[]) => void;
  setPinnedChains: (chains: string[]) => void;
  addPinnedChain: (chain: string) => void;
  removePinnedChain: (chain: string) => void;
  addCustomRPC: (chainId: string, rpc: string) => void;
  removeCustomRPC: (chainId: string) => void;
  setMatteredChainBalances: (
    balances: Record<string, { usdValue: number }>
  ) => void;
  reset: () => void;
}

const initialState = {
  currentChain: 'ETH' as string,
  chainList: [] as Chain[],
  pinnedChains: [] as string[],
  customRPCs: {} as Record<string, string>,
  matteredChainBalances: {} as Record<string, { usdValue: number }>,
};

export const useChainStore = create<ChainStore>()(
  persist(
    (set, get) => ({
      ...initialState,

      setCurrentChain: (chain) => {
        set({ currentChain: chain });
      },

      setChainList: (chains) => {
        set({ chainList: chains });
      },

      setPinnedChains: (chains) => {
        set({ pinnedChains: chains });
      },

      addPinnedChain: (chain) => {
        const { pinnedChains } = get();
        if (!pinnedChains.includes(chain)) {
          set({ pinnedChains: [...pinnedChains, chain] });
        }
      },

      removePinnedChain: (chain) => {
        const { pinnedChains } = get();
        set({ pinnedChains: pinnedChains.filter((c) => c !== chain) });
      },

      addCustomRPC: (chainId, rpc) => {
        const { customRPCs } = get();
        set({ customRPCs: { ...customRPCs, [chainId]: rpc } });
      },

      removeCustomRPC: (chainId) => {
        const { customRPCs } = get();
        const next = { ...customRPCs };
        delete next[chainId];
        set({ customRPCs: next });
      },

      setMatteredChainBalances: (balances) => {
        set({ matteredChainBalances: balances });
      },

      reset: () => {
        set(initialState);
      },
    }),
    {
      name: 'rabby-chain-store',
      partialize: (state) => ({
        currentChain: state.currentChain,
        pinnedChains: state.pinnedChains,
        customRPCs: state.customRPCs,
      }),
    }
  )
);
