/**
 * Constants barrel export.
 * Aggregates all constant modules for convenient single-path imports.
 */

export {
  CHAINS_ENUM,
  CHAIN_ID_MAP,
  CHAIN_ENUM_BY_ID,
  MAIN_CHAINS,
  L2_ENUMS,
  OP_STACK_ENUMS,
  ARB_LIKE_L2_CHAINS,
  CAN_ESTIMATE_L1_FEE_CHAINS,
} from './chains';
export type { ChainInfo } from './chains';

export {
  KEYRING_TYPE,
  KEYRING_CLASS,
  HARDWARE_KEYRING_TYPES,
  HARDWARE_BRANDS,
  KEYRING_CATEGORY,
  KEYRING_CATEGORY_MAP,
  KEYRING_TYPE_TEXT,
  BRAND_ALIAN_TYPE_TEXT,
  WALLET_BRAND_TYPES,
  WALLET_BRAND_CATEGORY,
  SORT_WEIGHT,
} from './keyring';

export {
  GAS_LEVEL_TEXT,
  DEFAULT_GAS_LIMIT,
  MINIMUM_GAS_LIMIT,
  DEFAULT_GAS_LIMIT_RATIO,
  DEFAULT_GAS_LIMIT_BUFFER,
  SAFE_GAS_LIMIT_RATIO,
  SAFE_GAS_LIMIT_BUFFER,
  SWAP_FEE_PRECISION,
} from './gas';

// ---------------------------------------------------------------------------
// Misc constants (not large enough for their own file)
// ---------------------------------------------------------------------------

/** Rabby API base URL */
export const INITIAL_OPENAPI_URL = 'https://api.rabby.io';

/** Rabby testnet API base URL */
export const INITIAL_TESTNET_OPENAPI_URL = 'https://api.testnet.rabby.io';
