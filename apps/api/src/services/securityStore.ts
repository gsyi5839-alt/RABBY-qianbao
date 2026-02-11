import { v4 as uuidv4 } from 'uuid';
import type {
  SecurityRule,
  PhishingEntry,
  ContractWhitelistEntry,
  SecurityAlert,
  SecuritySeverity,
  SecurityStatus,
  ContractStatus,
  AlertStatus,
} from '@rabby/shared';

const nowDate = () => new Date().toISOString().slice(0, 10);
const nowDateTime = () => new Date().toISOString().replace('T', ' ').slice(0, 16);

class SecurityStore {
  private rules = new Map<string, SecurityRule>();
  private phishing = new Map<string, PhishingEntry>();
  private contracts = new Map<string, ContractWhitelistEntry>();
  private alerts = new Map<string, SecurityAlert>();

  constructor() {
    const seedRules: Omit<SecurityRule, 'id'>[] = [
      { name: 'Large Transfer Alert', description: 'Flag transfers exceeding $100K', type: 'transfer', severity: 'high', enabled: true, triggers: 234, lastTriggered: '2024-01-15 14:20' },
      { name: 'New Contract Interaction', description: 'Alert on unverified contract calls', type: 'contract', severity: 'medium', enabled: true, triggers: 1892, lastTriggered: '2024-01-15 15:01' },
      { name: 'Phishing Site Detection', description: 'Block known phishing domains', type: 'phishing', severity: 'critical', enabled: true, triggers: 567, lastTriggered: '2024-01-15 12:45' },
      { name: 'Approval Revoke Warning', description: 'Warn on unlimited token approvals', type: 'approval', severity: 'high', enabled: true, triggers: 3421, lastTriggered: '2024-01-15 14:55' },
      { name: 'Flash Loan Detection', description: 'Detect flash loan attack patterns', type: 'contract', severity: 'critical', enabled: false, triggers: 12, lastTriggered: '2024-01-10 08:30' },
      { name: 'Suspicious Gas Spike', description: 'Alert when gas exceeds 5x normal', type: 'gas', severity: 'low', enabled: true, triggers: 89, lastTriggered: '2024-01-14 22:15' },
    ];
    seedRules.forEach((r) => this.createRule(r));

    const seedPhishing: Omit<PhishingEntry, 'id'>[] = [
      { address: '0xdead...beef1', domain: 'uniswap-airdrop.xyz', type: 'scam_site', reportedBy: 'community', addedDate: '2024-01-15', status: 'confirmed' },
      { address: '0xbad0...1234', domain: 'opensea-free-nft.com', type: 'phishing', reportedBy: 'automated', addedDate: '2024-01-14', status: 'confirmed' },
      { address: '0xf4ke...5678', domain: 'metamask-verify.net', type: 'impersonation', reportedBy: 'community', addedDate: '2024-01-13', status: 'confirmed' },
      { address: '0xsc4m...9abc', domain: 'aave-rewards.io', type: 'scam_site', reportedBy: 'automated', addedDate: '2024-01-12', status: 'pending' },
      { address: '0xh4ck...def0', domain: 'lido-stake.xyz', type: 'phishing', reportedBy: 'community', addedDate: '2024-01-11', status: 'confirmed' },
    ];
    seedPhishing.forEach((p) => this.createPhishing(p));

    const seedContracts: Omit<ContractWhitelistEntry, 'id'>[] = [
      { address: '0x7be8076f4ea4a4ad08075c2508e481d6c946d12b', name: 'OpenSea Exchange', chainId: '1', addedDate: '2024-01-12', status: 'active' },
      { address: '0x1111111254eeb25477b68fb85ed929f73a960582', name: '1inch Router', chainId: '1', addedDate: '2024-01-10', status: 'active' },
    ];
    seedContracts.forEach((c) => this.createContract(c));

    const seedAlerts: Omit<SecurityAlert, 'id'>[] = [
      { title: 'Spike in approval requests', level: 'medium', createdAt: nowDateTime(), status: 'open', description: 'Unusual increase in unlimited approvals in last hour.' },
      { title: 'Phishing domain reported', level: 'high', createdAt: nowDateTime(), status: 'open', description: 'Multiple reports for a new domain.' },
    ];
    seedAlerts.forEach((a) => this.createAlert(a));
  }

  // Rules
  listRules(): SecurityRule[] {
    return Array.from(this.rules.values());
  }

  createRule(data: Omit<SecurityRule, 'id'>): SecurityRule {
    const id = uuidv4();
    const rule: SecurityRule = { ...data, id };
    this.rules.set(id, rule);
    return rule;
  }

  updateRule(id: string, data: Partial<Omit<SecurityRule, 'id'>>): SecurityRule | undefined {
    const existing = this.rules.get(id);
    if (!existing) return undefined;
    const updated = { ...existing, ...data };
    this.rules.set(id, updated);
    return updated;
  }

  deleteRule(id: string): boolean {
    return this.rules.delete(id);
  }

  // Phishing
  listPhishing(): PhishingEntry[] {
    return Array.from(this.phishing.values());
  }

  createPhishing(data: Omit<PhishingEntry, 'id'>): PhishingEntry {
    const id = uuidv4();
    const entry: PhishingEntry = { ...data, id };
    this.phishing.set(id, entry);
    return entry;
  }

  updatePhishing(id: string, data: Partial<Omit<PhishingEntry, 'id'>>): PhishingEntry | undefined {
    const existing = this.phishing.get(id);
    if (!existing) return undefined;
    const updated = { ...existing, ...data };
    this.phishing.set(id, updated);
    return updated;
  }

  deletePhishing(id: string): boolean {
    return this.phishing.delete(id);
  }

  // Contracts
  listContracts(): ContractWhitelistEntry[] {
    return Array.from(this.contracts.values());
  }

  createContract(data: Omit<ContractWhitelistEntry, 'id'>): ContractWhitelistEntry {
    const id = uuidv4();
    const entry: ContractWhitelistEntry = { ...data, id };
    this.contracts.set(id, entry);
    return entry;
  }

  updateContract(id: string, data: Partial<Omit<ContractWhitelistEntry, 'id'>>): ContractWhitelistEntry | undefined {
    const existing = this.contracts.get(id);
    if (!existing) return undefined;
    const updated = { ...existing, ...data };
    this.contracts.set(id, updated);
    return updated;
  }

  deleteContract(id: string): boolean {
    return this.contracts.delete(id);
  }

  // Alerts
  listAlerts(): SecurityAlert[] {
    return Array.from(this.alerts.values());
  }

  createAlert(data: Omit<SecurityAlert, 'id'>): SecurityAlert {
    const id = uuidv4();
    const alert: SecurityAlert = { ...data, id };
    this.alerts.set(id, alert);
    return alert;
  }

  updateAlert(id: string, data: Partial<Omit<SecurityAlert, 'id'>>): SecurityAlert | undefined {
    const existing = this.alerts.get(id);
    if (!existing) return undefined;
    const updated = { ...existing, ...data };
    this.alerts.set(id, updated);
    return updated;
  }

  deleteAlert(id: string): boolean {
    return this.alerts.delete(id);
  }

  // Helpers
  static normalizeSeverity(value?: string): SecuritySeverity {
    const v = (value || '').toLowerCase();
    if (v === 'critical' || v === 'high' || v === 'medium' || v === 'low') return v;
    return 'low';
  }

  static normalizeStatus(value?: string): SecurityStatus {
    const v = (value || '').toLowerCase();
    return v === 'pending' ? 'pending' : 'confirmed';
  }

  static normalizeContractStatus(value?: string): ContractStatus {
    const v = (value || '').toLowerCase();
    return v === 'disabled' ? 'disabled' : 'active';
  }

  static normalizeAlertStatus(value?: string): AlertStatus {
    const v = (value || '').toLowerCase();
    return v === 'resolved' ? 'resolved' : 'open';
  }

  static nowDate() {
    return nowDate();
  }

  static nowDateTime() {
    return nowDateTime();
  }

  normalizeSeverity(value?: string) {
    return SecurityStore.normalizeSeverity(value);
  }

  normalizeStatus(value?: string) {
    return SecurityStore.normalizeStatus(value);
  }

  normalizeContractStatus(value?: string) {
    return SecurityStore.normalizeContractStatus(value);
  }

  normalizeAlertStatus(value?: string) {
    return SecurityStore.normalizeAlertStatus(value);
  }

  nowDate() {
    return SecurityStore.nowDate();
  }

  nowDateTime() {
    return SecurityStore.nowDateTime();
  }
}

export const securityStore = new SecurityStore();
