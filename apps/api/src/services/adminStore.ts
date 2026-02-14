import { db } from './database';
import type { DappEntry, ChainConfig } from '@rabby/shared';

export type { DappEntry, ChainConfig };

/**
 * Admin Store - Manages DApp directory and chain configurations
 * Migrated from in-memory Map to PostgreSQL
 */
class AdminStore {
  // --- DApps ---

  /**
   * List all DApps (with optional inclusion of disabled entries)
   */
  async listDapps(includeDisabled = false): Promise<DappEntry[]> {
    const sql = includeDisabled
      ? 'SELECT * FROM dapp_entries ORDER BY "order" ASC'
      : 'SELECT * FROM dapp_entries WHERE enabled = true ORDER BY "order" ASC';

    const result = await db.query<DappEntry>(sql);
    return result.rows;
  }

  /**
   * Get a single DApp by ID
   */
  async getDapp(id: string): Promise<DappEntry | undefined> {
    const result = await db.query<DappEntry>(
      'SELECT * FROM dapp_entries WHERE id = $1',
      [id]
    );
    return result.rows[0];
  }

  /**
   * Create a new DApp entry
   */
  async createDapp(data: Omit<DappEntry, 'id'>): Promise<DappEntry> {
    const result = await db.query<DappEntry>(
      `INSERT INTO dapp_entries
       (name, url, icon, category, description, chain, users, volume, status, added_date, risk_level, enabled, "order")
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
       RETURNING *`,
      [
        data.name,
        data.url,
        data.icon || null,
        data.category,
        data.description || null,
        data.chain || null,
        data.users || null,
        data.volume || null,
        data.status,
        data.addedDate || new Date().toISOString().slice(0, 10),
        data.riskLevel || 'medium',
        data.enabled ?? true,
        data.order ?? 0,
      ]
    );
    return result.rows[0];
  }

  /**
   * Update an existing DApp
   */
  async updateDapp(id: string, data: Partial<Omit<DappEntry, 'id'>>): Promise<DappEntry | undefined> {
    const existing = await this.getDapp(id);
    if (!existing) return undefined;

    const fields = [];
    const values = [];
    let paramIndex = 1;

    // Build dynamic UPDATE query
    if (data.name !== undefined) {
      fields.push(`name = $${paramIndex++}`);
      values.push(data.name);
    }
    if (data.url !== undefined) {
      fields.push(`url = $${paramIndex++}`);
      values.push(data.url);
    }
    if (data.icon !== undefined) {
      fields.push(`icon = $${paramIndex++}`);
      values.push(data.icon);
    }
    if (data.category !== undefined) {
      fields.push(`category = $${paramIndex++}`);
      values.push(data.category);
    }
    if (data.description !== undefined) {
      fields.push(`description = $${paramIndex++}`);
      values.push(data.description);
    }
    if (data.chain !== undefined) {
      fields.push(`chain = $${paramIndex++}`);
      values.push(data.chain);
    }
    if (data.users !== undefined) {
      fields.push(`users = $${paramIndex++}`);
      values.push(data.users);
    }
    if (data.volume !== undefined) {
      fields.push(`volume = $${paramIndex++}`);
      values.push(data.volume);
    }
    if (data.status !== undefined) {
      fields.push(`status = $${paramIndex++}`);
      values.push(data.status);
    }
    if (data.addedDate !== undefined) {
      fields.push(`added_date = $${paramIndex++}`);
      values.push(data.addedDate);
    }
    if (data.riskLevel !== undefined) {
      fields.push(`risk_level = $${paramIndex++}`);
      values.push(data.riskLevel);
    }
    if (data.enabled !== undefined) {
      fields.push(`enabled = $${paramIndex++}`);
      values.push(data.enabled);
    }
    if (data.order !== undefined) {
      fields.push(`"order" = $${paramIndex++}`);
      values.push(data.order);
    }

    if (fields.length === 0) return existing;

    values.push(id);
    const sql = `UPDATE dapp_entries SET ${fields.join(', ')} WHERE id = $${paramIndex} RETURNING *`;

    const result = await db.query<DappEntry>(sql, values);
    return result.rows[0];
  }

  /**
   * Delete a DApp
   */
  async deleteDapp(id: string): Promise<boolean> {
    const result = await db.query('DELETE FROM dapp_entries WHERE id = $1', [id]);
    return (result.rowCount ?? 0) > 0;
  }

  // --- Chains ---

  /**
   * List all chain configurations
   */
  async listChains(includeDisabled = false): Promise<ChainConfig[]> {
    const sql = includeDisabled
      ? 'SELECT * FROM chain_configs ORDER BY "order" ASC'
      : 'SELECT * FROM chain_configs WHERE enabled = true ORDER BY "order" ASC';

    const result = await db.query<ChainConfig>(sql);
    return result.rows;
  }

  /**
   * Get a single chain by ID
   */
  async getChain(id: string): Promise<ChainConfig | undefined> {
    const result = await db.query<ChainConfig>(
      'SELECT * FROM chain_configs WHERE id = $1',
      [id]
    );
    return result.rows[0];
  }

  /**
   * Create a new chain configuration
   */
  async createChain(data: Omit<ChainConfig, 'id'>): Promise<ChainConfig> {
    const result = await db.query<ChainConfig>(
      `INSERT INTO chain_configs
       (name, chain_id, symbol, rpc_url, explorer_url, logo, enabled, "order")
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [
        data.name,
        data.chainId,
        data.symbol || null,
        data.rpcUrl,
        data.explorerUrl || null,
        data.logo || null,
        data.enabled ?? true,
        data.order ?? 0,
      ]
    );
    return result.rows[0];
  }

  /**
   * Update an existing chain
   */
  async updateChain(id: string, data: Partial<Omit<ChainConfig, 'id'>>): Promise<ChainConfig | undefined> {
    const existing = await this.getChain(id);
    if (!existing) return undefined;

    const fields = [];
    const values = [];
    let paramIndex = 1;

    if (data.name !== undefined) {
      fields.push(`name = $${paramIndex++}`);
      values.push(data.name);
    }
    if (data.chainId !== undefined) {
      fields.push(`chain_id = $${paramIndex++}`);
      values.push(data.chainId);
    }
    if (data.symbol !== undefined) {
      fields.push(`symbol = $${paramIndex++}`);
      values.push(data.symbol);
    }
    if (data.rpcUrl !== undefined) {
      fields.push(`rpc_url = $${paramIndex++}`);
      values.push(data.rpcUrl);
    }
    if (data.explorerUrl !== undefined) {
      fields.push(`explorer_url = $${paramIndex++}`);
      values.push(data.explorerUrl);
    }
    if (data.logo !== undefined) {
      fields.push(`logo = $${paramIndex++}`);
      values.push(data.logo);
    }
    if (data.enabled !== undefined) {
      fields.push(`enabled = $${paramIndex++}`);
      values.push(data.enabled);
    }
    if (data.order !== undefined) {
      fields.push(`"order" = $${paramIndex++}`);
      values.push(data.order);
    }

    if (fields.length === 0) return existing;

    values.push(id);
    const sql = `UPDATE chain_configs SET ${fields.join(', ')} WHERE id = $${paramIndex} RETURNING *`;

    const result = await db.query<ChainConfig>(sql, values);
    return result.rows[0];
  }

  /**
   * Delete a chain configuration
   */
  async deleteChain(id: string): Promise<boolean> {
    const result = await db.query('DELETE FROM chain_configs WHERE id = $1', [id]);
    return (result.rowCount ?? 0) > 0;
  }
}

export const adminStore = new AdminStore();
