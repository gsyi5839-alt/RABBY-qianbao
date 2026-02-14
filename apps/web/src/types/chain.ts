/**
 * Chain-specific type definitions.
 */

/** Gas price information for a chain */
export interface ChainGas {
  /** Gas price in wei */
  gasPrice?: string;
  /** EIP-1559 base fee in wei */
  baseFee?: string;
  /** EIP-1559 priority fee (tip) in wei */
  priorityFee?: string;
  /** Estimated L1 data fee for L2 chains (in wei) */
  l1Fee?: string;
  /** Gas limit for the transaction */
  gasLimit?: number;
}

/** Aggregated balance for a single chain */
export interface ChainBalance {
  /** Chain server ID (e.g. 'eth', 'bsc') */
  chainServerId: string;
  /** Total USD value on this chain */
  usdValue: number;
  /** Native token balance (in ether units) */
  nativeTokenBalance: number;
  /** Native token USD value */
  nativeTokenUsdValue: number;
  /** Number of tokens held on this chain */
  tokenCount: number;
}

/** User-defined custom RPC endpoint */
export interface CustomRPCItem {
  /** Chain ID */
  chainId: number;
  /** Custom RPC URL */
  rpcUrl: string;
  /** Display name (optional) */
  name?: string;
  /** Whether this RPC is currently active */
  enable: boolean;
}

/** User-defined custom testnet chain */
export interface CustomTestnetItem {
  /** Chain ID */
  chainId: number;
  /** Chain name */
  name: string;
  /** RPC URL */
  rpcUrl: string;
  /** Native currency symbol */
  nativeTokenSymbol: string;
  /** Native currency decimals */
  nativeTokenDecimals: number;
  /** Block explorer URL (optional) */
  explorerUrl?: string;
}
