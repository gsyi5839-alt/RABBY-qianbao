/**
 * Keyring Service Framework
 *
 * Provides the abstract interface and base implementation for key management.
 *
 * IMPORTANT: This is the Phase 0 framework only.
 * Concrete cryptographic operations (HD derivation, mnemonic handling,
 * hardware wallet signing, etc.) will be implemented in Phase 1.
 *
 * The service manages:
 * - Lock / unlock state
 * - Account listing and selection
 * - Framework for multiple keyring types (HD, private key, hardware, watch-only)
 */

import type { StorageService } from '../storage';
import { secureStorage, generalStorage } from '../storage';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Account type identifiers, aligned with Rabby extension KEYRING_CLASS */
export enum KeyringType {
  HdKeyring = 'HD Key Tree',
  SimpleKeyring = 'Simple Key Pair',
  WatchAddressKeyring = 'Watch Address',
  HardwareKeyring = 'Hardware',
  GnosisKeyring = 'Gnosis',
  WalletConnect = 'WalletConnect',
}

export interface Account {
  type: string;
  address: string;
  brandName: string;
  alianName?: string;
  index?: number;
  balance?: number;
}

export interface KeyringMetadata {
  type: KeyringType;
  /** Number of accounts derived from this keyring */
  accountCount: number;
}

// ---------------------------------------------------------------------------
// KeyringService Interface
// ---------------------------------------------------------------------------

export interface KeyringService {
  /** Whether the keyring is currently locked (password required to access keys) */
  isLocked(): boolean;

  /** Lock the keyring, clearing any in-memory sensitive data */
  lock(): void;

  /**
   * Unlock the keyring with the user's password.
   * Returns true if the password was correct, false otherwise.
   */
  unlock(password: string): Promise<boolean>;

  /** Get all accounts across all keyrings */
  getAccounts(): Promise<Account[]>;

  /** Get the currently selected / active account */
  getCurrentAccount(): Account | null;

  /** Set the currently selected account */
  setCurrentAccount(account: Account): void;

  /** Check if the keyring has been initialised (first-time setup complete) */
  isInitialized(): Promise<boolean>;

  /** Get metadata about all managed keyrings */
  getKeyringMetadata(): Promise<KeyringMetadata[]>;
}

// ---------------------------------------------------------------------------
// Base Implementation (Phase 0 — framework only)
// ---------------------------------------------------------------------------

const ACCOUNTS_STORAGE_KEY = 'keyring_accounts';
const CURRENT_ACCOUNT_KEY = 'keyring_current_account';
const INITIALIZED_KEY = 'keyring_initialized';

export class BaseKeyringService implements KeyringService {
  private locked = true;
  private currentAccount: Account | null = null;
  private accounts: Account[] = [];

  private readonly secureStore: StorageService;
  private readonly generalStore: StorageService;

  constructor(
    secureStore: StorageService = secureStorage,
    generalStore: StorageService = generalStorage,
  ) {
    this.secureStore = secureStore;
    this.generalStore = generalStore;
  }

  // ---- Lock / Unlock ----

  isLocked(): boolean {
    return this.locked;
  }

  lock(): void {
    this.locked = true;
    // In Phase 1: clear derived keys from memory
  }

  async unlock(password: string): Promise<boolean> {
    // Phase 0: simple password verification placeholder
    // Phase 1: decrypt the encrypted vault with the password
    // and derive the master key from the mnemonic / stored seed
    const storedHash = await this.secureStore.get<string>('password_hash');
    if (!storedHash) {
      // No password set yet — first time setup will handle this
      this.locked = false;
      return true;
    }

    // Placeholder comparison — Phase 1 will use proper key derivation (PBKDF2/scrypt)
    const inputHash = await this.hashPassword(password);
    if (inputHash === storedHash) {
      this.locked = false;
      await this.loadAccounts();
      return true;
    }
    return false;
  }

  // ---- Accounts ----

  async getAccounts(): Promise<Account[]> {
    if (this.accounts.length === 0) {
      await this.loadAccounts();
    }
    return [...this.accounts];
  }

  getCurrentAccount(): Account | null {
    return this.currentAccount ? { ...this.currentAccount } : null;
  }

  setCurrentAccount(account: Account): void {
    this.currentAccount = { ...account };
    // Persist asynchronously (fire and forget)
    this.generalStore.set(CURRENT_ACCOUNT_KEY, this.currentAccount);
  }

  async isInitialized(): Promise<boolean> {
    const flag = await this.generalStore.get<boolean>(INITIALIZED_KEY);
    return flag === true;
  }

  async getKeyringMetadata(): Promise<KeyringMetadata[]> {
    // Phase 0: return empty; Phase 1 will enumerate actual keyrings
    return [];
  }

  // ---- Internal helpers ----

  private async loadAccounts(): Promise<void> {
    const stored =
      await this.generalStore.get<Account[]>(ACCOUNTS_STORAGE_KEY);
    this.accounts = stored ?? [];

    const current =
      await this.generalStore.get<Account>(CURRENT_ACCOUNT_KEY);
    this.currentAccount = current ?? (this.accounts[0] || null);
  }

  /**
   * Minimal password hashing placeholder.
   * Phase 1 MUST replace this with PBKDF2 or scrypt via WebCrypto.
   */
  private async hashPassword(password: string): Promise<string> {
    const encoder = new TextEncoder();
    const data = encoder.encode(password);
    const hashBuffer = await crypto.subtle.digest(
      'SHA-256',
      data as unknown as ArrayBuffer,
    );
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map((b) => b.toString(16).padStart(2, '0')).join('');
  }
}

// ---------------------------------------------------------------------------
// Default singleton instance
// ---------------------------------------------------------------------------

export const keyringService = new BaseKeyringService();
