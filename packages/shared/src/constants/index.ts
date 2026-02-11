/**
 * 共享常量（无 UI 依赖、无浏览器依赖）
 */

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

const createHardwareObject = () => ({
  BITBOX02: 'BitBox02 Hardware',
  TREZOR: 'Trezor Hardware',
  LEDGER: 'Ledger Hardware',
  ONEKEY: 'Onekey Hardware',
  GRIDPLUS: 'GridPlus Hardware',
  KEYSTONE: 'QR Hardware Wallet Device',
  IMKEY: 'imKey Hardware',
  NGRAVEZERO: 'QR Hardware Wallet Device',
});

export const KEYRING_CLASS = {
  PRIVATE_KEY: 'Simple Key Pair',
  MNEMONIC: 'HD Key Tree',
  HARDWARE: createHardwareObject(),
  WATCH: 'Watch Address',
  WALLETCONNECT: 'WalletConnect',
  GNOSIS: 'Gnosis',
  CoboArgus: 'CoboArgus',
  Coinbase: 'Coinbase',
} as const;

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

export const EVENTS = {
  BRIDGE_HISTORY_UPDATED: 'BRIDGE_HISTORY_UPDATED',
  broadcastToUI: 'broadcastToUI',
  broadcastToBackground: 'broadcastToBackground',
  TX_COMPLETED: 'TX_COMPLETED',
  SIGN_FINISHED: 'SIGN_FINISHED',
  TX_SUBMITTING: 'TX_SUBMITTING',
  WALLETCONNECT: {
    STATUS_CHANGED: 'WALLETCONNECT_STATUS_CHANGED',
    SESSION_STATUS_CHANGED: 'SESSION_STATUS_CHANGED',
    SESSION_ACCOUNT_CHANGED: 'SESSION_ACCOUNT_CHANGED',
    SESSION_NETWORK_DELAY: 'SESSION_NETWORK_DELAY',
    INIT: 'WALLETCONNECT_INIT',
    INITED: 'WALLETCONNECT_INITED',
    TRANSPORT_ERROR: 'TRANSPORT_ERROR',
    SCAN_ACCOUNT: 'SCAN_ACCOUNT',
  },
  GNOSIS: {
    TX_BUILT: 'TransactionBuilt',
    TX_CONFIRMED: 'TransactionConfirmed',
  },
  QRHARDWARE: {
    ACQUIRE_MEMSTORE_SUCCEED: 'ACQUIRE_MEMSTORE_SUCCEED',
  },
  LEDGER: {
    REJECTED: 'LEDGER_REJECTED',
    REJECT_APPROVAL: 'LEDGER_REJECT_APPROVAL',
  },
  COMMON_HARDWARE: {
    REJECTED: 'COMMON_HARDWARE_REJECTED',
  },
  ONEKEY: {
    REQUEST_PERMISSION_WEBUSB: 'ONEKEY_REQUEST_PERMISSION_WEBUI',
  },
  LOCK_WALLET: 'LOCK_WALLET',
  RELOAD_TX: 'RELOAD_TX',
  SIGN_BEGIN: 'SIGN_BEGIN',
  SIGN_WAITING_AMOUNTED: 'SIGN_WAITING_AMOUNTED',
  DIRECT_SIGN: 'DIRECT_SIGN',
  GAS_ACCOUNT: {
    LOG_IN: 'LOG_IN',
    LOG_OUT: 'LOG_OUT',
    CLOSE_WINDOW: 'CLOSE_WINDOW',
  },
  PERPS: {
    LOG_OUT: 'PERPS_LOG_OUT',
    HANDLE_CLICK_PRICE: 'PERPS_HANDLE_CLICK_PRICE',
    USER_INFO_HISTORY_TAB_CHANGED: 'PERPS_USER_INFO_HISTORY_TAB_CHANGED',
  },
  INNER_HISTORY_ITEM_PENDING: 'INNER_HISTORY_ITEM_PENDING',
  INNER_HISTORY_ITEM_COMPLETE: 'INNER_HISTORY_ITEM_COMPLETE',
  PERSIST_KEYRING: 'PERSIST_KEYRING',
  RELOAD_ACCOUNT_LIST: 'RELOAD_ACCOUNT_LIST',
  DESKTOP: {
    FOCUSED: 'DESKTOP_FOCUSED',
    SWITCH_PERPS_ACCOUNT: 'DESKTOP_SWITCH_PERPS_ACCOUNT',
  },
  RELOAD_APPROVAL: 'RELOAD_APPROVAL',
  INNER_DAPP_CHANGE: {
    ACCOUNT_CHANGED: 'INNER_DAPP_ACCOUNT_CHANGED',
    DAPP_CHANGED: 'INNER_DAPP_DAPP_CHANGED',
  },
} as const;

export const EVENTS_IN_BG = {
  ON_TX_COMPLETED: 'ON_TX_COMPLETED',
} as const;

export const INITIAL_OPENAPI_URL = 'https://api.rabby.io';
export const INITIAL_TESTNET_OPENAPI_URL = 'https://api.testnet.rabby.io';

export const SAFE_RPC_METHODS = [
  'eth_blockNumber',
  'eth_call',
  'eth_chainId',
  'eth_coinbase',
  'eth_estimateGas',
  'eth_gasPrice',
  'eth_getBalance',
  'eth_getCode',
  'eth_sendRawTransaction',
  'eth_sendTransaction',
  'eth_getTransactionReceipt',
  'eth_getTransactionCount',
  'net_version',
  'wallet_requestPermissions',
  'wallet_revokePermissions',
  'wallet_getPermissions',
] as const;

export const MINIMUM_GAS_LIMIT = 21000;

export const GAS_LEVEL_TEXT = {
  $unknown: 'Unknown',
  slow: 'Standard',
  normal: 'Fast',
  fast: 'Instant',
  custom: 'Custom',
} as const;

export const EXTENSION_MESSAGES = {
  CONNECTION_READY: 'CONNECTION_READY',
  READY: 'RABBY_EXTENSION_READY',
} as const;

export const SORT_WEIGHT: Record<string, number> = {
  [KEYRING_TYPE.HdKeyring]: 1,
  [KEYRING_TYPE.SimpleKeyring]: 2,
  [KEYRING_TYPE.HardwareKeyring]: 3,
  [KEYRING_TYPE.WalletConnectKeyring]: 4,
  [KEYRING_TYPE.GnosisKeyring]: 5,
  [KEYRING_TYPE.WatchAddressKeyring]: 999,
};

export const GAS_TOP_UP_ADDRESS = '0x7559e1bbe06e94aeed8000d5671ed424397d25b5';
export const GAS_TOP_UP_PAY_ADDRESS =
  '0x1f1f2bf8942861e6194fda1c0a9f13921c0cf117';
export const FREE_GAS_ADDRESS = '0x76dd65529dc6c073c1e0af2a5ecc78434bdbf7d9';

export const SWAP_FEE_PRECISION = 1e5;
export const DEFAULT_GAS_LIMIT_RATIO = 1.5;
export const DEFAULT_GAS_LIMIT_BUFFER = 0.95;

// --- Enums (platform-agnostic, no UI/browser dependencies) ---

export enum KEYRING_CATEGORY {
  Mnemonic = 'Mnemonic',
  PrivateKey = 'PrivateKey',
  WatchMode = 'WatchMode',
  Contract = 'Contract',
  Hardware = 'Hardware',
  WalletConnect = 'WalletConnect',
}

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

export enum TX_TYPE_ENUM {
  SEND = 1,
  APPROVE = 2,
  CANCEL_APPROVE = 3,
  CANCEL_TX = 4,
  SIGN_TX = 5,
}

export enum CANCEL_TX_TYPE {
  QUICK_CANCEL = 'QUICK_CANCEL',
  ON_CHAIN_CANCEL = 'ON_CHAIN_CANCEL',
  REMOVE_LOCAL_PENDING_TX = 'REMOVE_LOCAL_PENDING_TX',
}

export enum DARK_MODE_TYPE {
  'light' = 0,
  'dark' = 1,
  'system' = 2,
}

export enum SIGN_PERMISSION_TYPES {
  MAINNET_AND_TESTNET = 'MAINNET_AND_TESTNET',
  TESTNET = 'TESTNET',
}

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
  [KEYRING_CLASS.HARDWARE.KEYSTONE]: 'Imported by QRCode Base',
  [KEYRING_CLASS.HARDWARE.NGRAVEZERO]: 'Imported by QRCode Base',
  [KEYRING_CLASS.HARDWARE.IMKEY]: 'Imported by imKey',
};

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
  [KEYRING_CLASS.HARDWARE.KEYSTONE]: 'Keystone',
  [KEYRING_CLASS.HARDWARE.NGRAVEZERO]: 'NGRAVE ZERO',
  [KEYRING_CLASS.HARDWARE.IMKEY]: 'imKey',
};
