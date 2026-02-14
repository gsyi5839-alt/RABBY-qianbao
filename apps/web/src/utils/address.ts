/**
 * Ethereum address utility functions.
 */

/**
 * Truncate an address for display, e.g. "0x1234...abcd".
 * @param addr  Full 0x-prefixed address
 * @param start Number of leading characters to keep (default 6)
 * @param end   Number of trailing characters to keep (default 4)
 */
export function ellipsisAddress(addr: string, start = 6, end = 4): string {
  if (!addr) return '';
  if (addr.length <= start + end) return addr;
  return `${addr.slice(0, start)}...${addr.slice(-end)}`;
}

/**
 * Case-insensitive address comparison.
 * Returns `false` if either argument is falsy.
 */
export function isSameAddress(a: string, b: string): boolean {
  if (!a || !b) return false;
  return a.toLowerCase() === b.toLowerCase();
}

/**
 * Validate whether a string is a well-formed Ethereum address (0x + 40 hex chars).
 * This is a format check only -- it does not verify the EIP-55 checksum.
 */
export function isValidAddress(addr: string): boolean {
  if (!addr) return false;
  return /^0x[0-9a-fA-F]{40}$/.test(addr);
}

/**
 * Format an address for display.
 * If a `nameTag` is provided it is returned as-is.
 * Otherwise the address is ellipsized.
 */
export function formatAddressToShow(addr: string, nameTag?: string): string {
  if (nameTag) return nameTag;
  return ellipsisAddress(addr);
}
