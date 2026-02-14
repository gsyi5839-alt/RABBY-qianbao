/**
 * API Services — Unified Exports
 *
 * Re-exports all API modules and their default singleton instances
 * for convenient consumption throughout the web app.
 */

// ---------------------------------------------------------------------------
// Client
// ---------------------------------------------------------------------------
export {
  createApiClient,
  apiClient,
  ApiError,
  ApiTimeoutError,
  ApiNetworkError,
} from './client';
export type {
  ApiClient,
  ApiClientOptions,
  RequestInterceptor,
  ResponseInterceptor,
} from './client';

// ---------------------------------------------------------------------------
// Balance API
// ---------------------------------------------------------------------------
export { createBalanceApi, balanceApi } from './balance';
export type {
  BalanceApi,
  TotalBalanceResponse,
  ChainWithBalance,
  TokenItem,
  AssetItem,
} from './balance';

// ---------------------------------------------------------------------------
// Token API
// ---------------------------------------------------------------------------
export { createTokenApi, tokenApi } from './token';
export type {
  TokenApi,
  TokenEntityDetail,
  TokenItemWithEntity,
} from './token';

// ---------------------------------------------------------------------------
// Chain API
// ---------------------------------------------------------------------------
export { createChainApi, chainApi } from './chain';
export type {
  ChainApi,
  ServerChain,
  SupportedChain,
  ChainListItem,
  GasLevel,
  UsedChain,
} from './chain';

// ---------------------------------------------------------------------------
// Swap API
// ---------------------------------------------------------------------------
export { createSwapApi, swapApi } from './swap';
export type {
  SwapApi,
  SwapQuoteParams,
  SwapQuoteResult,
  DexInfo,
  SlippageStatus,
  SwapItem,
  SwapTradeList,
} from './swap';

// ---------------------------------------------------------------------------
// Bridge API
// ---------------------------------------------------------------------------
export { createBridgeApi, bridgeApi } from './bridge';
export type {
  BridgeApi,
  BridgeItem,
  BridgeAggregator,
  BridgeTokenPair,
  BridgeQuote,
  BridgeQuoteWithoutTx,
  BridgeHistory,
} from './bridge';

// ---------------------------------------------------------------------------
// History API
// ---------------------------------------------------------------------------
export { createHistoryApi, historyApi } from './history';
export type {
  HistoryApi,
  TxHistoryItem,
  TxHistoryResult,
  TxAllHistoryResult,
  ChainWithPendingCount,
} from './history';

// ---------------------------------------------------------------------------
// Security API
// ---------------------------------------------------------------------------
export { createSecurityApi, securityApi } from './security';
export type {
  SecurityApi,
  SecurityCheckDecision,
  SecurityCheckItem,
  SecurityCheckResponse,
  AddrDescResponse,
  ContractInfo,
  ContractCredit,
  ApprovalStatus,
  TokenApproval,
} from './security';
