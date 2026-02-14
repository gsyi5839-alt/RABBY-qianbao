/**
 * Keyring and wallet brand constants.
 * Migrated from `@rabby/shared` constants and extension `src/constant/index.ts`.
 */

// ---------------------------------------------------------------------------
// Keyring types — identifies how a key was created/imported
// ---------------------------------------------------------------------------

export const KEYRING_TYPE = {
  HdKeyring: 'HD Key Tree',
  SimpleKeyring: 'Simple Key Pair',
  HardwareKeyring: 'hardware',
  WatchAddressKeyring: 'Watch Address',
  WalletConnectKeyring: 'WalletConnect',
  GnosisKeyring: 'Gnosis',
  CoboArgusKeyring: 'CoboArgus',
  CoinbaseKeyring: 'Coinbase',
} as const;

// ---------------------------------------------------------------------------
// Keyring classes — string identifiers used in keyring instances
// ---------------------------------------------------------------------------

export const KEYRING_CLASS = {
  PRIVATE_KEY: 'Simple Key Pair',
  MNEMONIC: 'HD Key Tree',
  HARDWARE: {
    BITBOX02: 'BitBox02 Hardware',
    TREZOR: 'Trezor Hardware',
    LEDGER: 'Ledger Hardware',
    ONEKEY: 'Onekey Hardware',
    GRIDPLUS: 'GridPlus Hardware',
    KEYSTONE: 'QR Hardware Wallet Device',
    IMKEY: 'imKey Hardware',
    NGRAVEZERO: 'QR Hardware Wallet Device',
  },
  WATCH: 'Watch Address',
  WALLETCONNECT: 'WalletConnect',
  GNOSIS: 'Gnosis',
  CoboArgus: 'CoboArgus',
  Coinbase: 'Coinbase',
} as const;

// ---------------------------------------------------------------------------
// Hardware keyring metadata
// ---------------------------------------------------------------------------

export const HARDWARE_KEYRING_TYPES = {
  BitBox02: { type: 'BitBox02 Hardware', brandName: 'BitBox02' },
  Ledger: { type: 'Ledger Hardware', brandName: 'Ledger' },
  Trezor: { type: 'Trezor Hardware', brandName: 'Trezor' },
  Onekey: { type: 'Onekey Hardware', brandName: 'Onekey' },
  GridPlus: { type: 'GridPlus Hardware', brandName: 'GridPlus' },
  Keystone: { type: 'QR Hardware Wallet Device', brandName: 'Keystone' },
  NGRAVEZERO: { type: 'QR Hardware Wallet Device', brandName: 'NGRAVE ZERO' },
  ImKey: { type: 'imKey Hardware', brandName: 'imKey' },
} as const;

/** All hardware brand names */
export const HARDWARE_BRANDS = [
  'Ledger',
  'Trezor',
  'OneKey',
  'Keystone',
  'BitBox02',
  'GridPlus',
  'imKey',
  'NGRAVE ZERO',
] as const;

// ---------------------------------------------------------------------------
// Keyring categories
// ---------------------------------------------------------------------------

export enum KEYRING_CATEGORY {
  Mnemonic = 'Mnemonic',
  PrivateKey = 'PrivateKey',
  WatchMode = 'WatchMode',
  Contract = 'Contract',
  Hardware = 'Hardware',
  WalletConnect = 'WalletConnect',
}

/** Maps keyring class to its category */
export const KEYRING_CATEGORY_MAP: Record<string, KEYRING_CATEGORY> = {
  [KEYRING_CLASS.MNEMONIC]: KEYRING_CATEGORY.Mnemonic,
  [KEYRING_CLASS.PRIVATE_KEY]: KEYRING_CATEGORY.PrivateKey,
  [KEYRING_CLASS.WATCH]: KEYRING_CATEGORY.WatchMode,
  [KEYRING_CLASS.HARDWARE.LEDGER]: KEYRING_CATEGORY.Hardware,
  [KEYRING_CLASS.HARDWARE.ONEKEY]: KEYRING_CATEGORY.Hardware,
  [KEYRING_CLASS.HARDWARE.TREZOR]: KEYRING_CATEGORY.Hardware,
  [KEYRING_CLASS.HARDWARE.BITBOX02]: KEYRING_CATEGORY.Hardware,
  // KEYSTONE and NGRAVEZERO share the same class string 'QR Hardware Wallet Device'
  [KEYRING_CLASS.HARDWARE.KEYSTONE]: KEYRING_CATEGORY.Hardware,
  [KEYRING_CLASS.HARDWARE.GRIDPLUS]: KEYRING_CATEGORY.Hardware,
  [KEYRING_CLASS.HARDWARE.IMKEY]: KEYRING_CATEGORY.Hardware,
  [KEYRING_CLASS.WALLETCONNECT]: KEYRING_CATEGORY.WalletConnect,
  [KEYRING_CLASS.Coinbase]: KEYRING_CATEGORY.WalletConnect,
  [KEYRING_CLASS.GNOSIS]: KEYRING_CATEGORY.Contract,
};

// ---------------------------------------------------------------------------
// Keyring text descriptions
// ---------------------------------------------------------------------------

/** Human-readable text for each keyring type */
export const KEYRING_TYPE_TEXT: Record<string, string> = {
  [KEYRING_TYPE.HdKeyring]: 'Created by Seed Phrase',
  [KEYRING_TYPE.SimpleKeyring]: 'Imported by Private Key',
  [KEYRING_TYPE.WatchAddressKeyring]: 'Contact',
  [KEYRING_CLASS.HARDWARE.BITBOX02]: 'Imported by BitBox02',
  [KEYRING_CLASS.HARDWARE.LEDGER]: 'Imported by Ledger',
  [KEYRING_CLASS.HARDWARE.TREZOR]: 'Imported by Trezor',
  [KEYRING_CLASS.HARDWARE.ONEKEY]: 'Imported by Onekey',
  [KEYRING_CLASS.HARDWARE.GRIDPLUS]: 'Imported by GridPlus',
  [KEYRING_CLASS.GNOSIS]: 'Imported by Safe',
  // KEYSTONE and NGRAVEZERO share 'QR Hardware Wallet Device'; last write wins
  [KEYRING_CLASS.HARDWARE.KEYSTONE]: 'Imported by QRCode Base',
  [KEYRING_CLASS.HARDWARE.IMKEY]: 'Imported by imKey',
};

/** Short alias text for each keyring type */
export const BRAND_ALIAN_TYPE_TEXT: Record<string, string> = {
  [KEYRING_TYPE.HdKeyring]: 'Seed Phrase',
  [KEYRING_TYPE.SimpleKeyring]: 'Private Key',
  [KEYRING_TYPE.WatchAddressKeyring]: 'Contact',
  [KEYRING_CLASS.HARDWARE.LEDGER]: 'Ledger',
  [KEYRING_CLASS.HARDWARE.TREZOR]: 'Trezor',
  [KEYRING_CLASS.HARDWARE.ONEKEY]: 'Onekey',
  [KEYRING_CLASS.HARDWARE.BITBOX02]: 'BitBox02',
  [KEYRING_CLASS.GNOSIS]: 'Safe',
  [KEYRING_CLASS.HARDWARE.GRIDPLUS]: 'GridPlus',
  // KEYSTONE and NGRAVEZERO share the same key; keep last value
  [KEYRING_CLASS.HARDWARE.KEYSTONE]: 'Keystone',
  [KEYRING_CLASS.HARDWARE.IMKEY]: 'imKey',
};

// ---------------------------------------------------------------------------
// Wallet brand types
// ---------------------------------------------------------------------------

export enum WALLET_BRAND_TYPES {
  AMBER = 'AMBER',
  BITBOX02 = 'BITBOX02',
  COBO = 'COBO',
  FIREBLOCKS = 'FIREBLOCKS',
  IMTOKEN = 'IMTOKEN',
  JADE = 'JADE',
  LEDGER = 'LEDGER',
  MATHWALLET = 'MATHWALLET',
  ONEKEY = 'ONEKEY',
  TP = 'TP',
  TREZOR = 'TREZOR',
  TRUSTWALLET = 'TRUSTWALLET',
  GNOSIS = 'Gnosis',
  GRIDPLUS = 'GRIDPLUS',
  METAMASK = 'MetaMask',
  KEYSTONE = 'Keystone',
  COOLWALLET = 'CoolWallet',
  DEFIANT = 'Defiant',
  WALLETCONNECT = 'WALLETCONNECT',
  AIRGAP = 'AirGap',
  IMTOKENOFFLINE = 'imTokenOffline',
  Rainbow = 'Rainbow',
  Bitkeep = 'Bitget',
  Zerion = 'Zerion',
  CoboArgus = 'CoboArgus',
  MPCVault = 'MPCVault',
  Coinbase = 'Coinbase',
  IMKEY = 'IMKEY',
  NGRAVEZERO = 'NGRAVE ZERO',
  Utila = 'Utila',
}

export enum WALLET_BRAND_CATEGORY {
  MOBILE = 'mobile',
  HARDWARE = 'hardware',
  INSTITUTIONAL = 'institutional',
}

// ---------------------------------------------------------------------------
// Sort weight for keyrings in address list
// ---------------------------------------------------------------------------

export const SORT_WEIGHT: Record<string, number> = {
  [KEYRING_TYPE.HdKeyring]: 1,
  [KEYRING_TYPE.SimpleKeyring]: 2,
  [KEYRING_TYPE.HardwareKeyring]: 3,
  [KEYRING_TYPE.WalletConnectKeyring]: 4,
  [KEYRING_TYPE.GnosisKeyring]: 5,
  [KEYRING_TYPE.WatchAddressKeyring]: 999,
};
