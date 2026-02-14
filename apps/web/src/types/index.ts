/**
 * Web app type definitions.
 * Re-exports shared types and defines wallet-specific types.
 */

// Re-export all shared types
export type {
  ChainRaw,
  Chain,
  Account,
  TokenSpenderPair,
  TokenItem,
  TxHistoryItem,
  NFTItem,
  NFTCollection,
  TransactionRequest,
  SwapQuote,
  BridgeQuote,
  TokenApproval,
  GasAccountInfo,
  RabbyPointsInfo,
  SecuritySeverity,
  SecurityStatus,
  SecurityRule,
  PhishingEntry,
  ContractStatus,
  ContractWhitelistEntry,
  AlertStatus,
  SecurityAlert,
  DappEntry,
  ChainConfig,
  User,
  AuthPayload,
} from '@rabby/shared';

export type { ChainGas, ChainBalance, CustomRPCItem, CustomTestnetItem } from './chain';
export type {
  TransactionGroup,
  TransactionPending,
  SwapPendingTx,
  BridgePendingTx,
  SigningPayload,
  ExplainTxResponse,
} from './transaction';

// ---------------------------------------------------------------------------
// Wallet-specific types
// ---------------------------------------------------------------------------

/** Address type categorization */
export type AddressType =
  | 'hd'
  | 'simple'
  | 'hardware'
  | 'watch'
  | 'gnosis'
  | 'walletconnect';

/** Security assessment level for transaction signing */
export type SecurityLevel = 'safe' | 'warning' | 'danger' | 'forbidden';

/** Gas speed level */
export type GasLevel = 'slow' | 'normal' | 'fast' | 'custom';

/**
 * Extended wallet account, augments the shared `Account` type
 * with HD derivation and display metadata.
 */
export interface WalletAccount {
  type: string;
  address: string;
  brandName: string;
  alianName?: string;
  balance?: number;
  /** HD derivation index */
  index?: number;
  /** HD derivation path (e.g. "m/44'/60'/0'/0/0") */
  hdPath?: string;
  /** HD path type label (e.g. "Ledger Live", "BIP44 Standard") */
  hdPathType?: string;
}

/** User preference store persisted in local storage */
export interface PreferenceStore {
  /** Current theme ('light' | 'dark' | 'system') */
  theme: 'light' | 'dark' | 'system';
  /** UI locale code */
  language: string;
  /** Auto-lock timeout in minutes (0 = disabled) */
  autoLockTime: number;
  /** Whether the per-dapp account feature is enabled */
  isEnabledDappAccount: boolean;
  /** Last selected chain server ID */
  lastSelectedChain?: string;
  /** Whether to show test networks */
  showTestnet: boolean;
  /** Default token list sort order */
  tokenSortBy: 'value' | 'name' | 'amount';
  /** Whether the user has completed onboarding */
  isOnboardingCompleted: boolean;
}

/**
 * Approval request displayed in the signing popup.
 * Represents a pending DApp request that needs user confirmation.
 */
export interface ApprovalRequest {
  /** Unique request ID */
  id: string;
  /** Request method (e.g. 'eth_sendTransaction', 'personal_sign') */
  method: string;
  /** Raw request parameters */
  params: unknown[];
  /** Origin of the requesting DApp */
  origin: string;
  /** DApp name */
  name?: string;
  /** DApp icon URL */
  icon?: string;
  /** Associated chain ID */
  chainId?: number;
}

/** Signing request with resolved transaction or message data */
export interface SigningRequest {
  /** Unique request ID */
  id: string;
  /** Signing method */
  method: 'eth_sendTransaction' | 'personal_sign' | 'eth_signTypedData_v4' | string;
  /** Signer address */
  from: string;
  /** Chain ID */
  chainId: number;
  /** Raw request data */
  data: unknown;
  /** The approval request this signing corresponds to */
  approvalId?: string;
}
