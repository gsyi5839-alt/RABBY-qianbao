/**
 * Zustand Store - Unified Exports
 *
 * All application state is managed through Zustand stores.
 * Import individual stores or use this barrel export.
 */

// Store hooks
export { useAccountStore } from './account';
export { useChainStore } from './chain';
export { usePreferenceStore } from './preference';
export { useBalanceStore } from './balance';
export { useTransactionStore } from './transaction';
export { useApprovalStore } from './approval';

// Types re-exported for convenience
export type { AccountStore } from './account';
export type { ChainStore } from './chain';
export type { PreferenceStore, ThemeMode, Language } from './preference';
export type { BalanceStore, ChainBalance } from './balance';
export type {
  TransactionStore,
  TransactionPending,
} from './transaction';
export type {
  ApprovalStore,
  ApprovalRequest,
  ApprovalType,
} from './approval';

// Utility re-exports
export { isChainMattered } from './balance';
