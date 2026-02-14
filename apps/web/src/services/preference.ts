/**
 * Preference Service
 *
 * Manages user preferences for the Rabby web wallet.
 * Modelled after the extension's PreferenceService (src/background/service/preference.ts)
 * but adapted for the web/mobile environment using our StorageService abstraction.
 *
 * Responsibilities:
 * - Theme mode (light / dark / system)
 * - Locale / language
 * - Auto-lock timeout
 * - Pinned chains
 * - Custom / blocked tokens
 * - Gas cache per chain
 * - Hidden balance toggle
 * - Whitelist/security preferences
 */

import type { StorageService } from './storage';
import { generalStorage } from './storage';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type ThemeMode = 'light' | 'dark' | 'system';

export interface ChainGas {
  gasPrice?: number | null;
  gasLevel?: string | null;
  lastTimeSelect?: 'gasLevel' | 'gasPrice';
  expireAt?: number;
}

export type GasCache = Record<string, ChainGas>;

export interface TokenRef {
  address: string;
  chain: string;
}

export interface PreferenceData {
  themeMode: ThemeMode;
  locale: string;
  autoLockTime: number; // minutes; 0 = disabled
  pinnedChains: string[];
  customizedTokens: TokenRef[];
  blockedTokens: TokenRef[];
  collectionStarred: TokenRef[];
  gasCache: GasCache;
  hiddenBalance: boolean;
  isShowTestnet: boolean;
  isDefaultWallet: boolean;
  isEnabledWhitelist: boolean;
}

const DEFAULT_PREFERENCES: PreferenceData = {
  themeMode: 'light',
  locale: 'en',
  autoLockTime: 0,
  pinnedChains: [],
  customizedTokens: [],
  blockedTokens: [],
  collectionStarred: [],
  gasCache: {},
  hiddenBalance: false,
  isShowTestnet: false,
  isDefaultWallet: false,
  isEnabledWhitelist: false,
};

// ---------------------------------------------------------------------------
// Preference Service Interface
// ---------------------------------------------------------------------------

export interface PreferenceServiceInterface {
  /** Initialise / load preferences from storage */
  init(): Promise<void>;

  // Theme
  getTheme(): ThemeMode;
  setTheme(theme: ThemeMode): Promise<void>;

  // Language
  getLanguage(): string;
  setLanguage(lang: string): Promise<void>;

  // Auto-lock
  getAutoLockTime(): number;
  setAutoLockTime(minutes: number): Promise<void>;

  // Pinned chains
  getPinnedChains(): string[];
  setPinnedChains(chains: string[]): Promise<void>;
  addPinnedChain(chain: string): Promise<void>;
  removePinnedChain(chain: string): Promise<void>;

  // Tokens
  getCustomizedTokens(): TokenRef[];
  addCustomizedToken(token: TokenRef): Promise<void>;
  removeCustomizedToken(token: TokenRef): Promise<void>;

  getBlockedTokens(): TokenRef[];
  addBlockedToken(token: TokenRef): Promise<void>;
  removeBlockedToken(token: TokenRef): Promise<void>;

  // Collection starred
  getCollectionStarred(): TokenRef[];
  addCollectionStarred(token: TokenRef): Promise<void>;
  removeCollectionStarred(token: TokenRef): Promise<void>;

  // Gas cache
  getGasCache(chainId: string): ChainGas | null;
  setGasCache(chainId: string, gas: ChainGas): Promise<void>;

  // UI preferences
  getHiddenBalance(): boolean;
  setHiddenBalance(hidden: boolean): Promise<void>;

  getIsShowTestnet(): boolean;
  setIsShowTestnet(show: boolean): Promise<void>;

  getIsDefaultWallet(): boolean;
  setIsDefaultWallet(isDefault: boolean): Promise<void>;

  // Security
  getIsEnabledWhitelist(): boolean;
  setIsEnabledWhitelist(enabled: boolean): Promise<void>;

  /** Get a snapshot of all preferences */
  getAll(): PreferenceData;
}

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

const STORAGE_KEY = 'preferences';

function isSameAddress(a: string, b: string): boolean {
  return a.toLowerCase() === b.toLowerCase();
}

function isSameTokenRef(a: TokenRef, b: TokenRef): boolean {
  return isSameAddress(a.address, b.address) && a.chain === b.chain;
}

export class PreferenceService implements PreferenceServiceInterface {
  private data: PreferenceData = { ...DEFAULT_PREFERENCES };
  private storage: StorageService;
  private initialized = false;

  constructor(storage: StorageService = generalStorage) {
    this.storage = storage;
  }

  // ---- Lifecycle ----

  async init(): Promise<void> {
    if (this.initialized) return;
    const stored = await this.storage.get<PreferenceData>(STORAGE_KEY);
    if (stored) {
      this.data = { ...DEFAULT_PREFERENCES, ...stored };
    }
    this.initialized = true;
  }

  private async persist(): Promise<void> {
    await this.storage.set(STORAGE_KEY, this.data);
  }

  // ---- Theme ----

  getTheme(): ThemeMode {
    return this.data.themeMode;
  }

  async setTheme(theme: ThemeMode): Promise<void> {
    this.data.themeMode = theme;
    await this.persist();
  }

  // ---- Language ----

  getLanguage(): string {
    return this.data.locale;
  }

  async setLanguage(lang: string): Promise<void> {
    this.data.locale = lang;
    await this.persist();
  }

  // ---- Auto-lock ----

  getAutoLockTime(): number {
    return this.data.autoLockTime;
  }

  async setAutoLockTime(minutes: number): Promise<void> {
    this.data.autoLockTime = minutes;
    await this.persist();
  }

  // ---- Pinned Chains ----

  getPinnedChains(): string[] {
    return [...this.data.pinnedChains];
  }

  async setPinnedChains(chains: string[]): Promise<void> {
    this.data.pinnedChains = [...chains];
    await this.persist();
  }

  async addPinnedChain(chain: string): Promise<void> {
    if (!this.data.pinnedChains.includes(chain)) {
      this.data.pinnedChains = [...this.data.pinnedChains, chain];
      await this.persist();
    }
  }

  async removePinnedChain(chain: string): Promise<void> {
    this.data.pinnedChains = this.data.pinnedChains.filter(
      (c) => c !== chain,
    );
    await this.persist();
  }

  // ---- Customized Tokens ----

  getCustomizedTokens(): TokenRef[] {
    return [...this.data.customizedTokens];
  }

  async addCustomizedToken(token: TokenRef): Promise<void> {
    if (this.data.customizedTokens.some((t) => isSameTokenRef(t, token))) {
      return; // already added
    }
    this.data.customizedTokens = [...this.data.customizedTokens, token];
    await this.persist();
  }

  async removeCustomizedToken(token: TokenRef): Promise<void> {
    this.data.customizedTokens = this.data.customizedTokens.filter(
      (t) => !isSameTokenRef(t, token),
    );
    await this.persist();
  }

  // ---- Blocked Tokens ----

  getBlockedTokens(): TokenRef[] {
    return [...this.data.blockedTokens];
  }

  async addBlockedToken(token: TokenRef): Promise<void> {
    if (this.data.blockedTokens.some((t) => isSameTokenRef(t, token))) {
      return;
    }
    this.data.blockedTokens = [...this.data.blockedTokens, token];
    await this.persist();
  }

  async removeBlockedToken(token: TokenRef): Promise<void> {
    this.data.blockedTokens = this.data.blockedTokens.filter(
      (t) => !isSameTokenRef(t, token),
    );
    await this.persist();
  }

  // ---- Collection Starred ----

  getCollectionStarred(): TokenRef[] {
    return [...this.data.collectionStarred];
  }

  async addCollectionStarred(token: TokenRef): Promise<void> {
    if (this.data.collectionStarred.some((t) => isSameTokenRef(t, token))) {
      return;
    }
    this.data.collectionStarred = [...this.data.collectionStarred, token];
    await this.persist();
  }

  async removeCollectionStarred(token: TokenRef): Promise<void> {
    this.data.collectionStarred = this.data.collectionStarred.filter(
      (t) => !isSameTokenRef(t, token),
    );
    await this.persist();
  }

  // ---- Gas Cache ----

  getGasCache(chainId: string): ChainGas | null {
    return this.data.gasCache[chainId] ?? null;
  }

  async setGasCache(chainId: string, gas: ChainGas): Promise<void> {
    const existing = this.data.gasCache[chainId] ?? {};
    this.data.gasCache = {
      ...this.data.gasCache,
      [chainId]: {
        ...existing,
        ...gas,
        ...(gas.lastTimeSelect === 'gasPrice'
          ? { expireAt: Date.now() + 3_600_000 }
          : {}),
      },
    };
    await this.persist();
  }

  // ---- UI Preferences ----

  getHiddenBalance(): boolean {
    return this.data.hiddenBalance;
  }

  async setHiddenBalance(hidden: boolean): Promise<void> {
    this.data.hiddenBalance = hidden;
    await this.persist();
  }

  getIsShowTestnet(): boolean {
    return this.data.isShowTestnet;
  }

  async setIsShowTestnet(show: boolean): Promise<void> {
    this.data.isShowTestnet = show;
    await this.persist();
  }

  getIsDefaultWallet(): boolean {
    return this.data.isDefaultWallet;
  }

  async setIsDefaultWallet(isDefault: boolean): Promise<void> {
    this.data.isDefaultWallet = isDefault;
    await this.persist();
  }

  // ---- Security ----

  getIsEnabledWhitelist(): boolean {
    return this.data.isEnabledWhitelist;
  }

  async setIsEnabledWhitelist(enabled: boolean): Promise<void> {
    this.data.isEnabledWhitelist = enabled;
    await this.persist();
  }

  // ---- Snapshot ----

  getAll(): PreferenceData {
    return { ...this.data };
  }
}

// ---------------------------------------------------------------------------
// Default singleton instance
// ---------------------------------------------------------------------------

export const preferenceService = new PreferenceService();
