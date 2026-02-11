import { adminGet, adminPost, adminPut, adminDelete } from './client';
import type {
  DappEntry,
  ChainConfig,
  SecurityRule,
  PhishingEntry,
  ContractWhitelistEntry,
  SecurityAlert,
} from '@rabby/shared';

export type { DappEntry, ChainConfig, SecurityRule, PhishingEntry, ContractWhitelistEntry, SecurityAlert };

// --- Dapps ---
export function getDapps(all = true) {
  return adminGet<{ list: DappEntry[] }>(`/api/admin/dapps?all=${all}`);
}

export function createDapp(data: Omit<DappEntry, 'id'>) {
  return adminPost<DappEntry>('/api/admin/dapps', data);
}

export function updateDapp(id: string, data: Partial<DappEntry>) {
  return adminPut<DappEntry>(`/api/admin/dapps/${id}`, data);
}

export function deleteDapp(id: string) {
  return adminDelete<{ success: boolean }>(`/api/admin/dapps/${id}`);
}

// --- Chains ---
export function getChains(all = true) {
  return adminGet<{ list: ChainConfig[] }>(`/api/admin/chains?all=${all}`);
}

export function createChain(data: Omit<ChainConfig, 'id'>) {
  return adminPost<ChainConfig>('/api/admin/chains', data);
}

export function updateChain(id: string, data: Partial<ChainConfig>) {
  return adminPut<ChainConfig>(`/api/admin/chains/${id}`, data);
}

export function deleteChain(id: string) {
  return adminDelete<{ success: boolean }>(`/api/admin/chains/${id}`);
}

// --- Stats ---
export interface StatsResponse {
  totalUsers: number;
  totalAddresses: number;
  registrationByDay: Record<string, number>;
}

export function getStats() {
  return adminGet<StatsResponse>('/api/admin/stats');
}

// --- Security Whitelist ---
export interface WhitelistResponse {
  addresses: string[];
}

export function getWhitelist() {
  return adminGet<WhitelistResponse>('/api/security/whitelist');
}

export function addToWhitelist(address: string) {
  return adminPost<WhitelistResponse & { success: boolean }>('/api/security/whitelist', { address });
}

export function removeFromWhitelist(address: string) {
  return adminDelete<WhitelistResponse & { success: boolean }>(`/api/security/whitelist/${address}`);
}

// --- Security Rules ---

export function getSecurityRules() {
  return adminGet<{ list: SecurityRule[] }>('/api/security/rules');
}

export function createSecurityRule(data: Omit<SecurityRule, 'id'>) {
  return adminPost<SecurityRule>('/api/security/rules', data);
}

export function updateSecurityRule(id: string, data: Partial<SecurityRule>) {
  return adminPut<SecurityRule>(`/api/security/rules/${id}`, data);
}

export function deleteSecurityRule(id: string) {
  return adminDelete<{ success: boolean }>(`/api/security/rules/${id}`);
}

// --- Phishing Entries ---

export function getPhishingEntries() {
  return adminGet<{ list: PhishingEntry[] }>('/api/security/phishing');
}

export function createPhishingEntry(data: Omit<PhishingEntry, 'id'>) {
  return adminPost<PhishingEntry>('/api/security/phishing', data);
}

export function updatePhishingEntry(id: string, data: Partial<PhishingEntry>) {
  return adminPut<PhishingEntry>(`/api/security/phishing/${id}`, data);
}

export function deletePhishingEntry(id: string) {
  return adminDelete<{ success: boolean }>(`/api/security/phishing/${id}`);
}

// --- Contract Whitelist ---

export function getContractWhitelist() {
  return adminGet<{ list: ContractWhitelistEntry[] }>('/api/security/contracts');
}

export function createContractWhitelistEntry(data: Omit<ContractWhitelistEntry, 'id'>) {
  return adminPost<ContractWhitelistEntry>('/api/security/contracts', data);
}

export function updateContractWhitelistEntry(id: string, data: Partial<ContractWhitelistEntry>) {
  return adminPut<ContractWhitelistEntry>(`/api/security/contracts/${id}`, data);
}

export function deleteContractWhitelistEntry(id: string) {
  return adminDelete<{ success: boolean }>(`/api/security/contracts/${id}`);
}

// --- Security Alerts ---

export function getSecurityAlerts() {
  return adminGet<{ list: SecurityAlert[] }>('/api/security/alerts');
}

export function updateSecurityAlert(id: string, data: Partial<SecurityAlert>) {
  return adminPut<SecurityAlert>(`/api/security/alerts/${id}`, data);
}
