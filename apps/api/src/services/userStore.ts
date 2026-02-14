import { v4 as uuidv4 } from 'uuid';
import { db } from './database';
import type { User } from '@rabby/shared';

export type { User };

class UserStore {
  /**
   * Find user by Ethereum address
   */
  async findByAddress(address: string): Promise<User | undefined> {
    const lower = address.toLowerCase();
    const result = await db.query<User>(
      'SELECT * FROM users WHERE address = $1 LIMIT 1',
      [lower]
    );
    return result.rows[0];
  }

  /**
   * Find user by ID
   */
  async findById(id: string): Promise<User | undefined> {
    const result = await db.query<User>(
      'SELECT * FROM users WHERE id = $1 LIMIT 1',
      [id]
    );
    return result.rows[0];
  }

  /**
   * Create a new user
   */
  async create(address: string): Promise<User> {
    const lower = address.toLowerCase();

    // Check if user already exists
    const existing = await this.findByAddress(lower);
    if (existing) return existing;

    const result = await db.query<User>(
      `INSERT INTO users (address, addresses, role, created_at)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [lower, [lower], 'user', Date.now()]
    );

    return result.rows[0];
  }

  /**
   * Add an address to existing user
   */
  async addAddress(userId: string, address: string): Promise<boolean> {
    const user = await this.findById(userId);
    if (!user) return false;

    const lower = address.toLowerCase();
    if (user.addresses.includes(lower)) return true;

    // Check if address is already used by another user
    const existingUser = await this.findByAddress(lower);
    if (existingUser) return false;

    const newAddresses = [...user.addresses, lower];
    const result = await db.query(
      'UPDATE users SET addresses = $1 WHERE id = $2',
      [newAddresses, userId]
    );

    return result.rowCount! > 0;
  }

  /**
   * Remove an address from user
   */
  async removeAddress(userId: string, address: string): Promise<boolean> {
    const user = await this.findById(userId);
    if (!user) return false;

    const lower = address.toLowerCase();
    if (user.address === lower) return false; // Can't remove primary address

    const newAddresses = user.addresses.filter((a) => a !== lower);
    const result = await db.query(
      'UPDATE users SET addresses = $1 WHERE id = $2',
      [newAddresses, userId]
    );

    return result.rowCount! > 0;
  }

  /**
   * Count total users
   */
  async count(): Promise<number> {
    const result = await db.query<{ count: string }>(
      'SELECT COUNT(*) as count FROM users'
    );
    return parseInt(result.rows[0].count, 10);
  }

  /**
   * Get all users
   */
  async getAll(limit = 100, offset = 0): Promise<User[]> {
    const result = await db.query<User>(
      'SELECT * FROM users ORDER BY created_at DESC LIMIT $1 OFFSET $2',
      [limit, offset]
    );
    return result.rows;
  }
}

export const userStore = new UserStore();

// Nonce store for SIWE (keeping in-memory for temporary nonce storage)
class NonceStore {
  private nonces = new Map<string, { nonce: string; expiresAt: number }>();

  generate(address: string): string {
    const nonce = uuidv4();
    this.nonces.set(address.toLowerCase(), {
      nonce,
      expiresAt: Date.now() + 5 * 60 * 1000, // 5 minutes
    });
    return nonce;
  }

  verify(address: string, nonce: string): boolean {
    const entry = this.nonces.get(address.toLowerCase());
    if (!entry) return false;
    if (Date.now() > entry.expiresAt) {
      this.nonces.delete(address.toLowerCase());
      return false;
    }
    if (entry.nonce !== nonce) return false;
    this.nonces.delete(address.toLowerCase());
    return true;
  }
}

export const nonceStore = new NonceStore();
