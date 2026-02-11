import { v4 as uuidv4 } from 'uuid';
import type { DappEntry, ChainConfig } from '@rabby/shared';

export type { DappEntry, ChainConfig };

class AdminStore {
  private dapps = new Map<string, DappEntry>();
  private chains = new Map<string, ChainConfig>();

  constructor() {
    // Seed with default dapps
    const defaults: Omit<DappEntry, 'id' | 'enabled' | 'order'>[] = [
      { name: 'Uniswap', url: 'https://app.uniswap.org', icon: 'https://app.uniswap.org/favicon.ico', category: 'DEX' },
      { name: 'OpenSea', url: 'https://opensea.io', icon: 'https://opensea.io/favicon.ico', category: 'NFT' },
      { name: 'Aave', url: 'https://app.aave.com', icon: 'https://app.aave.com/favicon.ico', category: 'Lending' },
      { name: 'Compound', url: 'https://app.compound.finance', icon: 'https://app.compound.finance/favicon.ico', category: 'Lending' },
      { name: '1inch', url: 'https://app.1inch.io', icon: 'https://app.1inch.io/favicon.ico', category: 'DEX' },
      { name: 'Lido', url: 'https://lido.fi', icon: 'https://lido.fi/favicon.ico', category: 'Staking' },
      { name: 'Curve', url: 'https://curve.fi', icon: 'https://curve.fi/favicon.ico', category: 'DEX' },
      { name: 'GMX', url: 'https://app.gmx.io', icon: 'https://app.gmx.io/favicon.ico', category: 'Perps' },
      { name: 'dYdX', url: 'https://trade.dydx.exchange', icon: 'https://trade.dydx.exchange/favicon.ico', category: 'Perps' },
      { name: 'Raydium', url: 'https://raydium.io', icon: 'https://raydium.io/favicon.ico', category: 'DEX' },
    ];
    defaults.forEach((d, i) => {
      const id = uuidv4();
      this.dapps.set(id, { ...d, id, enabled: true, order: i });
    });
  }

  // --- Dapps ---
  listDapps(includeDisabled = false): DappEntry[] {
    const list = Array.from(this.dapps.values());
    return (includeDisabled ? list : list.filter((d) => d.enabled)).sort((a, b) => a.order - b.order);
  }

  getDapp(id: string): DappEntry | undefined {
    return this.dapps.get(id);
  }

  createDapp(data: Omit<DappEntry, 'id'>): DappEntry {
    const id = uuidv4();
    const entry: DappEntry = { ...data, id };
    this.dapps.set(id, entry);
    return entry;
  }

  updateDapp(id: string, data: Partial<Omit<DappEntry, 'id'>>): DappEntry | undefined {
    const existing = this.dapps.get(id);
    if (!existing) return undefined;
    const updated = { ...existing, ...data };
    this.dapps.set(id, updated);
    return updated;
  }

  deleteDapp(id: string): boolean {
    return this.dapps.delete(id);
  }

  // --- Chains ---
  listChains(includeDisabled = false): ChainConfig[] {
    const list = Array.from(this.chains.values());
    return (includeDisabled ? list : list.filter((c) => c.enabled)).sort((a, b) => a.order - b.order);
  }

  getChain(id: string): ChainConfig | undefined {
    return this.chains.get(id);
  }

  createChain(data: Omit<ChainConfig, 'id'>): ChainConfig {
    const id = uuidv4();
    const entry: ChainConfig = { ...data, id };
    this.chains.set(id, entry);
    return entry;
  }

  updateChain(id: string, data: Partial<Omit<ChainConfig, 'id'>>): ChainConfig | undefined {
    const existing = this.chains.get(id);
    if (!existing) return undefined;
    const updated = { ...existing, ...data };
    this.chains.set(id, updated);
    return updated;
  }

  deleteChain(id: string): boolean {
    return this.chains.delete(id);
  }
}

export const adminStore = new AdminStore();
