/**
 * Storage Abstraction Layer
 *
 * Provides a platform-agnostic storage interface with two implementations:
 * - GeneralStorage: for non-sensitive user preferences (localStorage)
 * - SecureStorage: for sensitive data like keys/credentials
 *   (currently uses localStorage with a prefix, but designed to be
 *    swapped to iOS Keychain / WebCrypto-based encrypted storage)
 *
 * Each storage implementation conforms to the StorageService interface.
 */

// ---------------------------------------------------------------------------
// Interface
// ---------------------------------------------------------------------------

export interface StorageService {
  /** Retrieve a value by key. Returns null if not found or on error. */
  get<T>(key: string): Promise<T | null>;

  /** Store a value under the given key. */
  set<T>(key: string, value: T): Promise<void>;

  /** Remove a single key. */
  remove(key: string): Promise<void>;

  /** Clear all entries managed by this storage instance. */
  clear(): Promise<void>;
}

// ---------------------------------------------------------------------------
// Storage Options
// ---------------------------------------------------------------------------

export interface StorageOptions {
  /** Prefix applied to all keys to avoid collisions (default: "rabby_") */
  prefix?: string;
}

// ---------------------------------------------------------------------------
// GeneralStorage (localStorage)
// ---------------------------------------------------------------------------

/**
 * General-purpose storage backed by `window.localStorage`.
 * Suitable for non-sensitive user preferences, UI state, etc.
 */
export class GeneralStorage implements StorageService {
  private readonly prefix: string;

  constructor(options: StorageOptions = {}) {
    this.prefix = options.prefix ?? 'rabby_';
  }

  private prefixed(key: string): string {
    return `${this.prefix}${key}`;
  }

  async get<T>(key: string): Promise<T | null> {
    try {
      const raw = localStorage.getItem(this.prefixed(key));
      if (raw === null) return null;
      return JSON.parse(raw) as T;
    } catch {
      return null;
    }
  }

  async set<T>(key: string, value: T): Promise<void> {
    localStorage.setItem(this.prefixed(key), JSON.stringify(value));
  }

  async remove(key: string): Promise<void> {
    localStorage.removeItem(this.prefixed(key));
  }

  async clear(): Promise<void> {
    const keysToRemove: string[] = [];
    for (let i = 0; i < localStorage.length; i++) {
      const k = localStorage.key(i);
      if (k && k.startsWith(this.prefix)) {
        keysToRemove.push(k);
      }
    }
    for (const k of keysToRemove) {
      localStorage.removeItem(k);
    }
  }
}

// ---------------------------------------------------------------------------
// SecureStorage (encrypted / keychain adapter)
// ---------------------------------------------------------------------------

/**
 * Adapter interface for platform-specific secure storage backends.
 *
 * Implementations:
 * - Web: encrypted-localStorage via WebCrypto (TODO: Phase 1)
 * - iOS: bridged to Keychain via native module (TODO: Phase 2)
 */
export interface SecureStorageBackend {
  getItem(key: string): Promise<string | null>;
  setItem(key: string, value: string): Promise<void>;
  removeItem(key: string): Promise<void>;
  clear(): Promise<void>;
}

/**
 * Default web backend — uses localStorage with a distinct prefix.
 *
 * NOTE: This is NOT truly encrypted. In Phase 1 this will be replaced
 * by a WebCrypto-backed implementation that encrypts values at rest.
 * The interface is intentionally async to accommodate that future change.
 */
class WebSecureStorageBackend implements SecureStorageBackend {
  private readonly prefix: string;

  constructor(prefix = 'rabby_secure_') {
    this.prefix = prefix;
  }

  private prefixed(key: string): string {
    return `${this.prefix}${key}`;
  }

  async getItem(key: string): Promise<string | null> {
    return localStorage.getItem(this.prefixed(key));
  }

  async setItem(key: string, value: string): Promise<void> {
    localStorage.setItem(this.prefixed(key), value);
  }

  async removeItem(key: string): Promise<void> {
    localStorage.removeItem(this.prefixed(key));
  }

  async clear(): Promise<void> {
    const keysToRemove: string[] = [];
    for (let i = 0; i < localStorage.length; i++) {
      const k = localStorage.key(i);
      if (k && k.startsWith(this.prefix)) {
        keysToRemove.push(k);
      }
    }
    for (const k of keysToRemove) {
      localStorage.removeItem(k);
    }
  }
}

/**
 * SecureStorage wraps a SecureStorageBackend and exposes the
 * standard StorageService interface.
 *
 * Usage:
 *   const secureStore = new SecureStorage();           // uses default web backend
 *   const iosStore = new SecureStorage(keychainBackend); // native adapter
 */
export class SecureStorage implements StorageService {
  private readonly backend: SecureStorageBackend;

  constructor(backend?: SecureStorageBackend) {
    this.backend = backend ?? new WebSecureStorageBackend();
  }

  async get<T>(key: string): Promise<T | null> {
    try {
      const raw = await this.backend.getItem(key);
      if (raw === null) return null;
      return JSON.parse(raw) as T;
    } catch {
      return null;
    }
  }

  async set<T>(key: string, value: T): Promise<void> {
    await this.backend.setItem(key, JSON.stringify(value));
  }

  async remove(key: string): Promise<void> {
    await this.backend.removeItem(key);
  }

  async clear(): Promise<void> {
    await this.backend.clear();
  }
}

// ---------------------------------------------------------------------------
// Default singleton instances
// ---------------------------------------------------------------------------

/** General storage for non-sensitive preferences and UI state */
export const generalStorage = new GeneralStorage();

/** Secure storage for sensitive data (keys, credentials) */
export const secureStorage = new SecureStorage();
