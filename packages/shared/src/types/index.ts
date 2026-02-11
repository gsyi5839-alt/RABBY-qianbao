/**
 * 共享类型定义
 */

export interface ChainRaw {
  id: number;
  name: string;
  hex: string;
  enum: string;
  serverId: string;
  network: string;
  nativeTokenSymbol: string;
  nativeTokenLogo: string;
  nativeTokenAddress: string;
  scanLink: string;
  nativeTokenDecimals: number;
  selectChainLogo?: string;
  eip: Record<string, boolean>;
  isTestnet?: boolean;
}

export interface Chain extends ChainRaw {
  logo: string;
  whiteLogo?: string;
}

export interface Account {
  type: string;
  address: string;
  brandName: string;
  alianName?: string;
  balance?: number;
}

export type TokenSpenderPair = {
  token: string;
  spender: string;
};

export interface TokenItem {
  id: string;
  chain: string;
  name: string;
  symbol: string;
  display_symbol?: string;
  decimals: number;
  logo_url: string;
  price: number;
  amount: number;
  raw_amount?: string;
  raw_amount_hex_str?: string;
  is_verified?: boolean;
  is_core?: boolean;
  is_scam?: boolean;
  is_suspicious?: boolean;
  time_at?: number;
}

export interface TxHistoryItem {
  id: string;
  chain: string;
  cate_id: string | null;
  tx?: {
    eth_gas_fee: number;
    usd_gas_fee: number;
    value: number;
    from: string;
    to: string;
    name: string;
    status: number;
  };
  project_id: string | null;
  time_at: number;
  sends: Array<{
    amount: number;
    to_addr: string;
    token_id: string;
    token?: TokenItem;
  }>;
  receives: Array<{
    amount: number;
    from_addr: string;
    token_id: string;
    token?: TokenItem;
  }>;
  is_scam?: boolean;
  token_approve?: {
    spender: string;
    token_id: string;
    value: number;
    token?: TokenItem;
  };
}

export interface NFTItem {
  id: string;
  contract_id: string;
  inner_id: string;
  chain: string;
  name: string;
  description?: string;
  content_type: string;
  content: string;
  thumbnail_url?: string;
  detail_url?: string;
  amount: number;
}

export interface NFTCollection {
  id: string;
  chain: string;
  name: string;
  symbol?: string;
  logo_url?: string;
  is_core: boolean;
  floor_price?: number;
  amount: number;
  nft_list: NFTItem[];
}

export interface TransactionRequest {
  from: string;
  to: string;
  value?: string;
  data?: string;
  gas?: string;
  gasPrice?: string;
  maxFeePerGas?: string;
  maxPriorityFeePerGas?: string;
  nonce?: number;
  chainId?: number;
}

export interface SwapQuote {
  dex_id: string;
  dex_name: string;
  dex_logo?: string;
  from_token: TokenItem;
  to_token: TokenItem;
  from_token_amount: string;
  to_token_amount: string;
  gas_fee_usd?: number;
  price_impact?: number;
  receive_token_amount: string;
  tx?: TransactionRequest;
}

export interface BridgeQuote {
  bridge_id: string;
  bridge_name: string;
  bridge_logo?: string;
  from_chain_id: string;
  to_chain_id: string;
  from_token: TokenItem;
  to_token: TokenItem;
  from_token_amount: string;
  to_token_amount: string;
  fee_token_amount?: string;
  duration?: number;
  tx?: TransactionRequest;
}

export interface TokenApproval {
  id: string;
  token: TokenItem;
  spender: {
    id: string;
    name?: string;
    logo_url?: string;
    protocol_id?: string;
    is_contract?: boolean;
    risk_level?: 'safe' | 'warning' | 'danger';
  };
  amount: number;
  is_unlimited: boolean;
}

export interface GasAccountInfo {
  account_id?: string;
  balance: number;
  chain_list: string[];
  sig?: string;
}

export interface RabbyPointsInfo {
  user_points: number;
  rank?: number;
  total_users?: number;
  campaigns: Array<{
    id: string;
    name: string;
    description: string;
    points: number;
    claimed: boolean;
    start_time: number;
    end_time: number;
  }>;
  referral_code?: string;
}

// --- Security ---

export type SecuritySeverity = 'low' | 'medium' | 'high' | 'critical';
export type SecurityStatus = 'confirmed' | 'pending';

export interface SecurityRule {
  id: string;
  name: string;
  description: string;
  type: string;
  severity: SecuritySeverity;
  enabled: boolean;
  triggers: number;
  lastTriggered?: string;
}

export interface PhishingEntry {
  id: string;
  address: string;
  domain: string;
  type: string;
  reportedBy: string;
  addedDate: string;
  status: SecurityStatus;
}

export type ContractStatus = 'active' | 'disabled';

export interface ContractWhitelistEntry {
  id: string;
  address: string;
  name?: string;
  chainId?: string;
  addedDate: string;
  status: ContractStatus;
}

export type AlertStatus = 'open' | 'resolved';

export interface SecurityAlert {
  id: string;
  title: string;
  level: SecuritySeverity;
  createdAt: string;
  status: AlertStatus;
  description?: string;
}

// --- Admin/API shared types ---

export interface DappEntry {
  id: string;
  name: string;
  url: string;
  icon: string;
  category: string;
  enabled: boolean;
  order: number;
}

export interface ChainConfig {
  id: string;
  chainId: number;
  name: string;
  nativeCurrency: { name: string; symbol: string; decimals: number };
  rpcUrl: string;
  explorerUrl: string;
  enabled: boolean;
  order: number;
}

export interface User {
  id: string;
  address: string;
  addresses: string[];
  role: 'user' | 'admin';
  createdAt: number;
}

export interface AuthPayload {
  userId: string;
  address: string;
  role: 'user' | 'admin';
}
