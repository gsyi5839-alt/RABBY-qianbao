import { v4 as uuidv4 } from 'uuid';
import type { User } from '@rabby/shared';

export type { User };

class UserStore {
  private users = new Map<string, User>();
  private addressIndex = new Map<string, string>(); // address -> userId

  findByAddress(address: string): User | undefined {
    const userId = this.addressIndex.get(address.toLowerCase());
    if (!userId) return undefined;
    return this.users.get(userId);
  }

  findById(id: string): User | undefined {
    return this.users.get(id);
  }

  create(address: string): User {
    const lower = address.toLowerCase();
    const existing = this.findByAddress(lower);
    if (existing) return existing;

    const user: User = {
      id: uuidv4(),
      address: lower,
      addresses: [lower],
      role: 'user',
      createdAt: Date.now(),
    };
    this.users.set(user.id, user);
    this.addressIndex.set(lower, user.id);
    return user;
  }

  addAddress(userId: string, address: string): boolean {
    const user = this.users.get(userId);
    if (!user) return false;
    const lower = address.toLowerCase();
    if (user.addresses.includes(lower)) return true;
    if (this.addressIndex.has(lower)) return false;
    user.addresses.push(lower);
    this.addressIndex.set(lower, userId);
    return true;
  }

  removeAddress(userId: string, address: string): boolean {
    const user = this.users.get(userId);
    if (!user) return false;
    const lower = address.toLowerCase();
    if (lower === user.address) return false; // cannot remove primary
    user.addresses = user.addresses.filter((a) => a !== lower);
    this.addressIndex.delete(lower);
    return true;
  }

  count(): number {
    return this.users.size;
  }

  getAll(): User[] {
    return Array.from(this.users.values());
  }
}

export const userStore = new UserStore();

// Nonce store for SIWE
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
