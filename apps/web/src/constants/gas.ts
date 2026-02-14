/**
 * Gas-related constants.
 * Migrated from `@rabby/shared` and extension `src/constant/index.ts`.
 */

/** Human-readable labels for each gas level */
export const GAS_LEVEL_TEXT = {
  $unknown: 'Unknown',
  slow: 'Standard',
  normal: 'Fast',
  fast: 'Instant',
  custom: 'Custom',
} as const;

/** Default minimum gas limit for a simple ETH transfer */
export const DEFAULT_GAS_LIMIT = 21000;

/** Minimum gas limit allowed */
export const MINIMUM_GAS_LIMIT = 21000;

/** Multiplier applied to estimated gas to provide headroom */
export const DEFAULT_GAS_LIMIT_RATIO = 1.5;

/** Buffer factor applied to the gas estimate */
export const DEFAULT_GAS_LIMIT_BUFFER = 0.95;

/**
 * Per-chain overrides for gas limit ratio.
 * Key is the decimal chain ID as a string.
 */
export const SAFE_GAS_LIMIT_RATIO: Record<string, number> = {
  '1284': 2,
  '1285': 2,
  '1287': 2,
};

/**
 * Per-chain overrides for gas limit buffer.
 * Key is the decimal chain ID as a string.
 */
export const SAFE_GAS_LIMIT_BUFFER: Record<string, number> = {
  '996': 0.86,
  '49088': 0.86,
  '3068': 0.86,
};

/** Precision used for swap fee calculations */
export const SWAP_FEE_PRECISION = 1e5;
