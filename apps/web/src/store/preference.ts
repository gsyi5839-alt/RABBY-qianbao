import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export type ThemeMode = 'light' | 'dark' | 'system';
export type Language = 'en' | 'zh';

export interface PreferenceStore {
  // State
  theme: ThemeMode;
  language: Language;
  autoLockTime: number; // minutes, 0 = never
  isShowTestnet: boolean;
  hiddenBalance: boolean;
  isEnabledWhitelist: boolean;
  isEnabledDappAccount: boolean;
  pinnedChain: string[];
  reserveGasOnSendToken: boolean;

  // Actions
  setTheme: (theme: ThemeMode) => void;
  setLanguage: (lang: Language) => void;
  setAutoLockTime: (minutes: number) => void;
  setShowTestnet: (show: boolean) => void;
  setHiddenBalance: (hidden: boolean) => void;
  toggleWhitelist: () => void;
  toggleDappAccount: () => void;
  setPinnedChain: (chains: string[]) => void;
  setReserveGasOnSendToken: (reserve: boolean) => void;
  reset: () => void;
}

const initialState = {
  theme: 'system' as ThemeMode,
  language: 'en' as Language,
  autoLockTime: 0,
  isShowTestnet: false,
  hiddenBalance: false,
  isEnabledWhitelist: false,
  isEnabledDappAccount: false,
  pinnedChain: [] as string[],
  reserveGasOnSendToken: false,
};

export const usePreferenceStore = create<PreferenceStore>()(
  persist(
    (set, get) => ({
      ...initialState,

      setTheme: (theme) => {
        set({ theme });
      },

      setLanguage: (lang) => {
        set({ language: lang });
      },

      setAutoLockTime: (minutes) => {
        set({ autoLockTime: minutes });
      },

      setShowTestnet: (show) => {
        set({ isShowTestnet: show });
      },

      setHiddenBalance: (hidden) => {
        set({ hiddenBalance: hidden });
      },

      toggleWhitelist: () => {
        const { isEnabledWhitelist } = get();
        set({ isEnabledWhitelist: !isEnabledWhitelist });
      },

      toggleDappAccount: () => {
        const { isEnabledDappAccount } = get();
        set({ isEnabledDappAccount: !isEnabledDappAccount });
      },

      setPinnedChain: (chains) => {
        set({ pinnedChain: chains });
      },

      setReserveGasOnSendToken: (reserve) => {
        set({ reserveGasOnSendToken: reserve });
      },

      reset: () => {
        set(initialState);
      },
    }),
    {
      name: 'rabby-preference-store',
    }
  )
);
