import { create } from 'zustand';
import type { TokenItem } from '@rabby/shared';

export interface ChainBalance {
  id: string;
  name: string;
  usdValue: number;
  percentage: number;
  logo?: string;
}

export interface BalanceStore {
  // State
  totalBalance: number;
  evmBalance: number;
  chainBalances: Record<string, number>;
  matteredChainBalances: ChainBalance[];
  tokenList: TokenItem[];
  customizeTokenList: TokenItem[];
  blockedTokenList: TokenItem[];
  isLoading: boolean;
  balanceFromCache: boolean;

  // Actions
  setTotalBalance: (balance: number) => void;
  setEvmBalance: (balance: number) => void;
  setChainBalances: (balances: Record<string, number>) => void;
  setMatteredChainBalances: (balances: ChainBalance[]) => void;
  setTokenList: (tokens: TokenItem[]) => void;
  setCustomizeTokenList: (tokens: TokenItem[]) => void;
  setBlockedTokenList: (tokens: TokenItem[]) => void;
  setIsLoading: (loading: boolean) => void;
  setBalanceFromCache: (fromCache: boolean) => void;
  fetchBalance: (address: string) => Promise<void>;
  fetchTokenList: (address: string) => Promise<void>;
  resetTokenList: () => void;
  reset: () => void;
}

const initialState = {
  totalBalance: 0,
  evmBalance: 0,
  chainBalances: {} as Record<string, number>,
  matteredChainBalances: [] as ChainBalance[],
  tokenList: [] as TokenItem[],
  customizeTokenList: [] as TokenItem[],
  blockedTokenList: [] as TokenItem[],
  isLoading: false,
  balanceFromCache: false,
};

/**
 * Determine whether a chain balance is "mattered" (significant):
 * 1. Greater than $1 and has percentage > 1%
 * 2. Or >= $1000
 *
 * Ported from extension's isChainMattered logic
 */
export function isChainMattered(
  chainUsdValue: number,
  totalUsdValue: number
): boolean {
  return (
    chainUsdValue >= 1000 ||
    (chainUsdValue > 1 && chainUsdValue / totalUsdValue > 0.01)
  );
}

export const useBalanceStore = create<BalanceStore>()((set, get) => ({
  ...initialState,

  setTotalBalance: (balance) => {
    set({ totalBalance: balance });
  },

  setEvmBalance: (balance) => {
    set({ evmBalance: balance });
  },

  setChainBalances: (balances) => {
    set({ chainBalances: balances });
  },

  setMatteredChainBalances: (balances) => {
    set({ matteredChainBalances: balances });
  },

  setTokenList: (tokens) => {
    set({ tokenList: tokens });
  },

  setCustomizeTokenList: (tokens) => {
    set({ customizeTokenList: tokens });
  },

  setBlockedTokenList: (tokens) => {
    set({ blockedTokenList: tokens });
  },

  setIsLoading: (loading) => {
    set({ isLoading: loading });
  },

  setBalanceFromCache: (fromCache) => {
    set({ balanceFromCache: fromCache });
  },

  fetchBalance: async (address: string) => {
    if (!address) return;
    set({ isLoading: true });
    try {
      // TODO: Call balance API service when available
      // const result = await balanceApi.getAddressBalance(address);
      // set({
      //   totalBalance: result.total_usd_value,
      //   chainBalances: result.chain_list.reduce(...),
      //   isLoading: false,
      //   balanceFromCache: false,
      // });
    } catch (error) {
      console.error('[BalanceStore] fetchBalance error:', error);
    } finally {
      set({ isLoading: false });
    }
  },

  fetchTokenList: async (address: string) => {
    if (!address) return;
    set({ isLoading: true });
    try {
      // TODO: Call token list API service when available
      // const tokens = await tokenApi.getTokenList(address);
      // set({ tokenList: tokens, isLoading: false });
    } catch (error) {
      console.error('[BalanceStore] fetchTokenList error:', error);
    } finally {
      set({ isLoading: false });
    }
  },

  resetTokenList: () => {
    set({
      tokenList: [],
      customizeTokenList: [],
      blockedTokenList: [],
    });
  },

  reset: () => {
    set(initialState);
  },
}));
