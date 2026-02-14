/**
 * Browser storage (localStorage / sessionStorage) wrapper utilities.
 * Provides safe JSON serialization and error handling.
 */

/**
 * Read a value from localStorage, deserializing from JSON.
 * Returns `null` if the key does not exist or parsing fails.
 */
export function getLocalStorage<T = unknown>(key: string): T | null {
  try {
    const raw = localStorage.getItem(key);
    if (raw === null) return null;
    return JSON.parse(raw) as T;
  } catch {
    return null;
  }
}

/**
 * Write a value to localStorage, serializing to JSON.
 */
export function setLocalStorage<T = unknown>(key: string, value: T): void {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {
    // Storage quota exceeded or private mode — silently ignore
  }
}

/**
 * Remove a key from localStorage.
 */
export function removeLocalStorage(key: string): void {
  try {
    localStorage.removeItem(key);
  } catch {
    // ignore
  }
}

/**
 * Read a value from sessionStorage, deserializing from JSON.
 * Returns `null` if the key does not exist or parsing fails.
 */
export function getSessionStorage<T = unknown>(key: string): T | null {
  try {
    const raw = sessionStorage.getItem(key);
    if (raw === null) return null;
    return JSON.parse(raw) as T;
  } catch {
    return null;
  }
}

/**
 * Write a value to sessionStorage, serializing to JSON.
 */
export function setSessionStorage<T = unknown>(key: string, value: T): void {
  try {
    sessionStorage.setItem(key, JSON.stringify(value));
  } catch {
    // Storage quota exceeded — silently ignore
  }
}

/**
 * Remove a key from sessionStorage.
 */
export function removeSessionStorage(key: string): void {
  try {
    sessionStorage.removeItem(key);
  } catch {
    // ignore
  }
}
