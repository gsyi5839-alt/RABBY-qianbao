/**
 * Hooks - Unified Exports
 *
 * All business-logic hooks for the web app.
 * Import individual hooks or use this barrel export.
 */

// Core wallet hook
export { useWallet } from './useWallet';

// Account hooks
export { useCurrentAccount, useCurrentAddress } from './useCurrentAccount';
export { useAccount } from './backgroundState/useAccount';

// Balance hook
export { useCurrentBalance } from './useCurrentBalance';

// Chain hook
export { useChain } from './useChain';

// Token hook
export { useTokenList } from './useTokenList';
export type { TokenSortField, TokenSortOrder } from './useTokenList';

// Contact hook
export { useContact } from './useContact';
export type { ContactItem } from './useContact';

// Preference hooks
export {
  usePreference,
  useThemeModeOnMain,
  useThemeMode,
} from './usePreference';
