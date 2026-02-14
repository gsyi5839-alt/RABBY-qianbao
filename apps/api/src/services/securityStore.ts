import { db } from './database';
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

/**
 * Security Store - Manages security rules, phishing database, contract whitelist, and alerts
 * Migrated from in-memory Map to PostgreSQL
 */
class SecurityStore {
  // --- Security Rules ---

  async listRules(): Promise<SecurityRule[]> {
    const result = await db.query<SecurityRule>('SELECT * FROM security_rules ORDER BY severity DESC, name ASC');
    return result.rows;
  }

  async getRule(id: string): Promise<SecurityRule | undefined> {
    const result = await db.query<SecurityRule>('SELECT * FROM security_rules WHERE id = $1', [id]);
    return result.rows[0];
  }

  async createRule(data: Omit<SecurityRule, 'id'>): Promise<SecurityRule> {
    const result = await db.query<SecurityRule>(
      `INSERT INTO security_rules (name, description, type, severity, enabled, triggers, last_triggered)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [data.name, data.description || null, data.type, data.severity, data.enabled ?? true, data.triggers ?? 0, data.lastTriggered || null]
    );
    return result.rows[0];
  }

  async updateRule(id: string, data: Partial<Omit<SecurityRule, 'id'>>): Promise<SecurityRule | undefined> {
    const existing = await this.getRule(id);
    if (!existing) return undefined;

    const fields = [];
    const values = [];
    let paramIndex = 1;

    if (data.name !== undefined) {
      fields.push(`name = $${paramIndex++}`);
      values.push(data.name);
    }
    if (data.description !== undefined) {
      fields.push(`description = $${paramIndex++}`);
      values.push(data.description);
    }
    if (data.type !== undefined) {
      fields.push(`type = $${paramIndex++}`);
      values.push(data.type);
    }
    if (data.severity !== undefined) {
      fields.push(`severity = $${paramIndex++}`);
      values.push(data.severity);
    }
    if (data.enabled !== undefined) {
      fields.push(`enabled = $${paramIndex++}`);
      values.push(data.enabled);
    }
    if (data.triggers !== undefined) {
      fields.push(`triggers = $${paramIndex++}`);
      values.push(data.triggers);
    }
    if (data.lastTriggered !== undefined) {
      fields.push(`last_triggered = $${paramIndex++}`);
      values.push(data.lastTriggered);
    }

    if (fields.length === 0) return existing;

    values.push(id);
    const sql = `UPDATE security_rules SET ${fields.join(', ')} WHERE id = $${paramIndex} RETURNING *`;
    const result = await db.query<SecurityRule>(sql, values);
    return result.rows[0];
  }

  async deleteRule(id: string): Promise<boolean> {
    const result = await db.query('DELETE FROM security_rules WHERE id = $1', [id]);
    return (result.rowCount ?? 0) > 0;
  }

  // --- Phishing Entries ---

  async listPhishing(): Promise<PhishingEntry[]> {
    const result = await db.query<PhishingEntry>('SELECT * FROM phishing_entries ORDER BY added_date DESC');
    return result.rows;
  }

  async getPhishing(id: string): Promise<PhishingEntry | undefined> {
    const result = await db.query<PhishingEntry>('SELECT * FROM phishing_entries WHERE id = $1', [id]);
    return result.rows[0];
  }

  async createPhishing(data: Omit<PhishingEntry, 'id'>): Promise<PhishingEntry> {
    const result = await db.query<PhishingEntry>(
      `INSERT INTO phishing_entries (address, domain, type, reported_by, added_date, status)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [data.address, data.domain, data.type, data.reportedBy || null, data.addedDate || nowDate(), data.status || 'pending']
    );
    return result.rows[0];
  }

  async updatePhishing(id: string, data: Partial<Omit<PhishingEntry, 'id'>>): Promise<PhishingEntry | undefined> {
    const existing = await this.getPhishing(id);
    if (!existing) return undefined;

    const fields = [];
    const values = [];
    let paramIndex = 1;

    if (data.address !== undefined) {
      fields.push(`address = $${paramIndex++}`);
      values.push(data.address);
    }
    if (data.domain !== undefined) {
      fields.push(`domain = $${paramIndex++}`);
      values.push(data.domain);
    }
    if (data.type !== undefined) {
      fields.push(`type = $${paramIndex++}`);
      values.push(data.type);
    }
    if (data.reportedBy !== undefined) {
      fields.push(`reported_by = $${paramIndex++}`);
      values.push(data.reportedBy);
    }
    if (data.addedDate !== undefined) {
      fields.push(`added_date = $${paramIndex++}`);
      values.push(data.addedDate);
    }
    if (data.status !== undefined) {
      fields.push(`status = $${paramIndex++}`);
      values.push(data.status);
    }

    if (fields.length === 0) return existing;

    values.push(id);
    const sql = `UPDATE phishing_entries SET ${fields.join(', ')} WHERE id = $${paramIndex} RETURNING *`;
    const result = await db.query<PhishingEntry>(sql, values);
    return result.rows[0];
  }

  async deletePhishing(id: string): Promise<boolean> {
    const result = await db.query('DELETE FROM phishing_entries WHERE id = $1', [id]);
    return (result.rowCount ?? 0) > 0;
  }

  // --- Contract Whitelist ---

  async listContracts(): Promise<ContractWhitelistEntry[]> {
    const result = await db.query<ContractWhitelistEntry>('SELECT * FROM contract_whitelist ORDER BY name ASC');
    return result.rows;
  }

  async getContract(id: string): Promise<ContractWhitelistEntry | undefined> {
    const result = await db.query<ContractWhitelistEntry>('SELECT * FROM contract_whitelist WHERE id = $1', [id]);
    return result.rows[0];
  }

  async createContract(data: Omit<ContractWhitelistEntry, 'id'>): Promise<ContractWhitelistEntry> {
    const result = await db.query<ContractWhitelistEntry>(
      `INSERT INTO contract_whitelist (address, name, chain_id, added_date, status)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [data.address, data.name, data.chainId, data.addedDate || nowDate(), data.status || 'active']
    );
    return result.rows[0];
  }

  async updateContract(id: string, data: Partial<Omit<ContractWhitelistEntry, 'id'>>): Promise<ContractWhitelistEntry | undefined> {
    const existing = await this.getContract(id);
    if (!existing) return undefined;

    const fields = [];
    const values = [];
    let paramIndex = 1;

    if (data.address !== undefined) {
      fields.push(`address = $${paramIndex++}`);
      values.push(data.address);
    }
    if (data.name !== undefined) {
      fields.push(`name = $${paramIndex++}`);
      values.push(data.name);
    }
    if (data.chainId !== undefined) {
      fields.push(`chain_id = $${paramIndex++}`);
      values.push(data.chainId);
    }
    if (data.addedDate !== undefined) {
      fields.push(`added_date = $${paramIndex++}`);
      values.push(data.addedDate);
    }
    if (data.status !== undefined) {
      fields.push(`status = $${paramIndex++}`);
      values.push(data.status);
    }

    if (fields.length === 0) return existing;

    values.push(id);
    const sql = `UPDATE contract_whitelist SET ${fields.join(', ')} WHERE id = $${paramIndex} RETURNING *`;
    const result = await db.query<ContractWhitelistEntry>(sql, values);
    return result.rows[0];
  }

  async deleteContract(id: string): Promise<boolean> {
    const result = await db.query('DELETE FROM contract_whitelist WHERE id = $1', [id]);
    return (result.rowCount ?? 0) > 0;
  }

  // --- Security Alerts ---

  async listAlerts(): Promise<SecurityAlert[]> {
    const result = await db.query<SecurityAlert>('SELECT * FROM security_alerts ORDER BY created_at DESC');
    return result.rows;
  }

  async getAlert(id: string): Promise<SecurityAlert | undefined> {
    const result = await db.query<SecurityAlert>('SELECT * FROM security_alerts WHERE id = $1', [id]);
    return result.rows[0];
  }

  async createAlert(data: Omit<SecurityAlert, 'id'>): Promise<SecurityAlert> {
    const result = await db.query<SecurityAlert>(
      `INSERT INTO security_alerts (title, level, description, status, created_at, resolved_at)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [data.title, data.level, data.description || null, data.status || 'open', data.createdAt || nowDateTime(), data.resolvedAt || null]
    );
    return result.rows[0];
  }

  async updateAlert(id: string, data: Partial<Omit<SecurityAlert, 'id'>>): Promise<SecurityAlert | undefined> {
    const existing = await this.getAlert(id);
    if (!existing) return undefined;

    const fields = [];
    const values = [];
    let paramIndex = 1;

    if (data.title !== undefined) {
      fields.push(`title = $${paramIndex++}`);
      values.push(data.title);
    }
    if (data.level !== undefined) {
      fields.push(`level = $${paramIndex++}`);
      values.push(data.level);
    }
    if (data.description !== undefined) {
      fields.push(`description = $${paramIndex++}`);
      values.push(data.description);
    }
    if (data.status !== undefined) {
      fields.push(`status = $${paramIndex++}`);
      values.push(data.status);
    }
    if (data.createdAt !== undefined) {
      fields.push(`created_at = $${paramIndex++}`);
      values.push(data.createdAt);
    }
    if (data.resolvedAt !== undefined) {
      fields.push(`resolved_at = $${paramIndex++}`);
      values.push(data.resolvedAt);
    }

    if (fields.length === 0) return existing;

    values.push(id);
    const sql = `UPDATE security_alerts SET ${fields.join(', ')} WHERE id = $${paramIndex} RETURNING *`;
    const result = await db.query<SecurityAlert>(sql, values);
    return result.rows[0];
  }

  async deleteAlert(id: string): Promise<boolean> {
    const result = await db.query('DELETE FROM security_alerts WHERE id = $1', [id]);
    return (result.rowCount ?? 0) > 0;
  }
}

export const securityStore = new SecurityStore();
