/**
 * Transaction-related type definitions.
 */

import type { TokenItem, TxHistoryItem, TransactionRequest } from '@rabby/shared';

/** A group of related transactions (e.g. approve + swap) */
export interface TransactionGroup {
  /** Chain server ID */
  chainServerId: string;
  /** Chain ID */
  chainId: number;
  /** Nonce shared by the group */
  nonce: number;
  /** Timestamp of the first tx in the group */
  createdAt: number;
  /** Whether the group is still pending */
  isPending: boolean;
  /** Whether the group has been completed */
  isCompleted: boolean;
  /** Explanation text */
  explain?: string;
  /** List of transaction hashes in this group */
  txHashes: string[];
  /** The most recent transaction in the group */
  maxTx?: TransactionPending;
}

/** A pending (unconfirmed) transaction */
export interface TransactionPending {
  /** Transaction hash */
  hash: string;
  /** Chain server ID */
  chainServerId: string;
  /** Chain ID */
  chainId: number;
  /** Sender address */
  from: string;
  /** Recipient address */
  to: string;
  /** Value in wei */
  value: string;
  /** Transaction nonce */
  nonce: number;
  /** Gas price in wei */
  gasPrice?: string;
  /** Max fee per gas (EIP-1559) */
  maxFeePerGas?: string;
  /** Max priority fee per gas (EIP-1559) */
  maxPriorityFeePerGas?: string;
  /** Gas limit */
  gas: string;
  /** Input data */
  data?: string;
  /** Creation timestamp (ms) */
  createdAt: number;
  /** Whether the user has requested speed-up */
  isSpeedUp?: boolean;
  /** Whether the user has requested cancel */
  isCancel?: boolean;
  /** Decoded transaction explanation */
  explain?: ExplainTxResponse;
  /** Site origin that requested the transaction */
  origin?: string;
  /** Raw request that created this pending tx */
  rawTx?: TransactionRequest;
}

/** A pending swap transaction */
export interface SwapPendingTx {
  /** Transaction hash */
  hash: string;
  /** Chain server ID */
  chainServerId: string;
  /** Chain ID */
  chainId: number;
  /** DEX identifier */
  dexId: string;
  /** Source token */
  payToken: TokenItem;
  /** Destination token */
  receiveToken: TokenItem;
  /** Amount paid (in token units) */
  payAmount: string;
  /** Expected receive amount */
  receiveAmount: string;
  /** Creation timestamp (ms) */
  createdAt: number;
  /** Completion timestamp (ms) */
  completedAt?: number;
}

/** A pending bridge transaction */
export interface BridgePendingTx {
  /** Transaction hash on the source chain */
  hash: string;
  /** Source chain server ID */
  fromChainServerId: string;
  /** Destination chain server ID */
  toChainServerId: string;
  /** Source chain ID */
  fromChainId: number;
  /** Destination chain ID */
  toChainId: number;
  /** Bridge protocol identifier */
  bridgeId: string;
  /** Source token */
  fromToken: TokenItem;
  /** Destination token */
  toToken: TokenItem;
  /** Amount sent */
  fromAmount: string;
  /** Expected receive amount */
  toAmount: string;
  /** Creation timestamp (ms) */
  createdAt: number;
  /** Completion timestamp (ms) */
  completedAt?: number;
  /** Transaction hash on the destination chain */
  toHash?: string;
}

/** Signing payload passed to hardware/WalletConnect signers */
export interface SigningPayload {
  /** Signing method */
  method: string;
  /** Raw data to sign */
  data: unknown;
  /** Signer address */
  from: string;
  /** Chain ID */
  chainId: number;
}

/** Decoded transaction explanation returned by the security engine */
export interface ExplainTxResponse {
  /** Short description of what the tx does */
  typeText?: string;
  /** Detailed action type (e.g. 'token_approval', 'send_token') */
  actionType?: string;
  /** Human-readable action name */
  actionName?: string;
  /** Tokens sent in this tx */
  sends?: Array<{
    tokenId: string;
    amount: number;
    to: string;
    token?: TokenItem;
  }>;
  /** Tokens received in this tx */
  receives?: Array<{
    tokenId: string;
    amount: number;
    from: string;
    token?: TokenItem;
  }>;
}
