/**
 * Security API Service
 *
 * Wraps Rabby OpenAPI security-related endpoints.
 * Reference: OpenApiService.checkOrigin, checkTx, addrDesc,
 *            getContractInfo, isSuspiciousToken, isOriginVerified
 */

import type { ApiClient } from './client';
import { apiClient } from './client';
import type { TokenItem } from './balance';

// ---------------------------------------------------------------------------
// Types (aligned with @rabby-wallet/rabby-api types)
// ---------------------------------------------------------------------------

export type SecurityCheckDecision =
  | 'pass'
  | 'warning'
  | 'danger'
  | 'forbidden'
  | 'loading'
  | 'pending';

export interface SecurityCheckItem {
  alert: string;
  description: string;
  is_alert: boolean;
  decision: SecurityCheckDecision;
  id: number;
}

export interface SecurityCheckResponse {
  decision: SecurityCheckDecision;
  alert: string;
  danger_list: SecurityCheckItem[];
  warning_list: SecurityCheckItem[];
  forbidden_list: SecurityCheckItem[];
  forbidden_count: number;
  warning_count: number;
  danger_count: number;
  alert_count: number;
  trace_id: string;
  error?: { code: number; msg: string } | null;
}

export interface Cex {
  id: string;
  logo_url: string;
  name: string;
  is_deposit: boolean;
}

export interface ContractDesc {
  multisig?: { id: string; logo_url: string; name: string };
  create_at: number;
  is_danger?: boolean | null;
}

export interface AddrDescResponse {
  desc: {
    cex?: Cex;
    contract?: Record<string, ContractDesc>;
    usd_value: number;
    protocol?: Record<
      string,
      { id: string; logo_url: string; name: string }
    >;
    born_at: number;
    is_danger: boolean | null;
    is_spam: boolean | null;
    is_scam: boolean | null;
    name: string;
    id: string;
  };
}

export interface ContractCredit {
  value: null | number;
  rank_at: number | null;
}

export interface ContractInfo {
  id: string;
  credit: ContractCredit;
  is_token: boolean;
  token_approval_exposure: number;
  top_nft_approval_exposure: number;
  spend_usd_value: number;
  top_nft_spend_usd_value: number;
  create_at: number;
  name: string | null;
  protocol: {
    id: string;
    logo_url: string;
    name: string;
  } | null;
  is_danger: {
    auto: null | boolean;
    edit: null | boolean;
  };
  is_phishing: boolean | null;
}

export interface Tx {
  chainId: number;
  data: string;
  from: string;
  gas?: string;
  gasLimit?: string;
  maxFeePerGas?: string;
  maxPriorityFeePerGas?: string;
  gasPrice?: string;
  nonce: string;
  to: string;
  value: string;
}

export interface ApprovalStatus {
  chain: string;
  token_approval_danger_cnt: number;
  nft_approval_danger_cnt: number;
}

export interface TokenApproval {
  id: string;
  name: string;
  symbol: string;
  logo_url: string;
  chain: string;
  price: number;
  balance: number;
  spenders: Array<{
    id: string;
    permit2_id?: string;
    value: number;
    exposure_usd: number;
    protocol: {
      id: string;
      name: string;
      logo_url: string;
      chain: string;
    };
    risk_alert: string;
    risk_level: string;
    last_approve_at: number | null;
  }>;
  sum_exposure_usd: number;
}

// ---------------------------------------------------------------------------
// Security API
// ---------------------------------------------------------------------------

export interface SecurityApi {
  /**
   * Check an address for security info (CEX, contract, danger flags, etc.).
   * Maps to: GET /v1/user/addr_desc?id={address}
   */
  checkAddress(address: string): Promise<AddrDescResponse>;

  /**
   * Check a contract's safety on a specific chain.
   * Maps to: GET /v1/contract/info?id={contractAddress}&chain_id={chainId}
   */
  checkContract(
    contractAddress: string,
    chainId: string,
  ): Promise<ContractInfo | null>;

  /**
   * Get security engine rules (approval status per chain).
   * Maps to: GET /v1/user/approval_status?id={address}
   */
  getSecurityEngineRules(
    address: string,
  ): Promise<ApprovalStatus[]>;

  /**
   * Check origin security.
   * Maps to: POST /v1/engine/check_origin
   */
  checkOrigin(
    address: string,
    origin: string,
  ): Promise<SecurityCheckResponse>;

  /**
   * Check transaction security.
   * Maps to: POST /v1/engine/check_tx
   */
  checkTx(
    tx: Tx,
    origin: string,
    address: string,
  ): Promise<SecurityCheckResponse>;

  /**
   * Check if a token is suspicious.
   * Maps to: GET /v1/token/is_suspicious?id={tokenId}&chain_id={chainId}
   */
  isSuspiciousToken(
    tokenId: string,
    chainId: string,
  ): Promise<{ is_suspicious: boolean }>;

  /**
   * Check if an origin is verified.
   * Maps to: GET /v1/origin/is_verified?origin={origin}
   */
  isOriginVerified(origin: string): Promise<{ is_verified: boolean | null }>;

  /**
   * Check if an address is blocked.
   * Maps to: GET /v1/user/is_blocked?id={address}
   */
  isBlockedAddress(address: string): Promise<{ is_blocked: boolean }>;

  /**
   * Get the contract credit rating.
   * Maps to: GET /v1/contract/credit?id={contractId}&chain_id={chainId}
   */
  getContractCredit(
    contractId: string,
    chainId: string,
  ): Promise<ContractCredit>;

  /**
   * Get token approvals for an address on a chain.
   * Maps to: GET /v1/user/token_authorized_list?id={address}&chain_id={chainId}
   */
  getTokenApprovals(
    address: string,
    chainId: string,
  ): Promise<TokenApproval[]>;

  /**
   * Check for address spoofing.
   * Maps to: POST /v1/check/spoofing
   */
  checkSpoofing(params: {
    from: string;
    to: string;
  }): Promise<{ is_spoofing: boolean }>;
}

export function createSecurityApi(
  client: ApiClient = apiClient,
): SecurityApi {
  return {
    async checkAddress(address: string): Promise<AddrDescResponse> {
      return client.get<AddrDescResponse>('/v1/user/addr_desc', {
        id: address,
      });
    },

    async checkContract(
      contractAddress: string,
      chainId: string,
    ): Promise<ContractInfo | null> {
      return client.get<ContractInfo | null>('/v1/contract/info', {
        id: contractAddress,
        chain_id: chainId,
      });
    },

    async getSecurityEngineRules(
      address: string,
    ): Promise<ApprovalStatus[]> {
      return client.get<ApprovalStatus[]>('/v1/user/approval_status', {
        id: address,
      });
    },

    async checkOrigin(
      address: string,
      origin: string,
    ): Promise<SecurityCheckResponse> {
      return client.get<SecurityCheckResponse>('/v1/engine/check_origin', {
        user_addr: address,
        origin,
      });
    },

    async checkTx(
      tx: Tx,
      origin: string,
      address: string,
    ): Promise<SecurityCheckResponse> {
      return client.post<SecurityCheckResponse>('/v1/engine/check_tx', {
        tx,
        origin,
        user_addr: address,
      });
    },

    async isSuspiciousToken(
      tokenId: string,
      chainId: string,
    ): Promise<{ is_suspicious: boolean }> {
      return client.get('/v1/token/is_suspicious', {
        id: tokenId,
        chain_id: chainId,
      });
    },

    async isOriginVerified(
      origin: string,
    ): Promise<{ is_verified: boolean | null }> {
      return client.get('/v1/origin/is_verified', { origin });
    },

    async isBlockedAddress(
      address: string,
    ): Promise<{ is_blocked: boolean }> {
      return client.get('/v1/user/is_blocked', { id: address });
    },

    async getContractCredit(
      contractId: string,
      chainId: string,
    ): Promise<ContractCredit> {
      return client.get<ContractCredit>('/v1/contract/credit', {
        id: contractId,
        chain_id: chainId,
      });
    },

    async getTokenApprovals(
      address: string,
      chainId: string,
    ): Promise<TokenApproval[]> {
      return client.get<TokenApproval[]>('/v1/user/token_authorized_list', {
        id: address,
        chain_id: chainId,
      });
    },

    async checkSpoofing(params: {
      from: string;
      to: string;
    }): Promise<{ is_spoofing: boolean }> {
      return client.post('/v1/check/spoofing', params);
    },
  };
}

/** Default singleton security API instance */
export const securityApi = createSecurityApi();
