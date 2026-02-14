import { Pool, PoolClient, QueryResult, QueryResultRow } from 'pg';
import { config } from '../config';

/**
 * PostgreSQL Database Manager
 * Manages database connection pool and provides query helpers
 */
class Database {
  private pool: Pool;
  private static instance: Database;

  private constructor() {
    this.pool = new Pool({
      host: config.database.host,
      port: config.database.port,
      database: config.database.name,
      user: config.database.user,
      password: config.database.password,
      max: 20, // Maximum pool size
      idleTimeoutMillis: 30000, // Close idle clients after 30 seconds
      connectionTimeoutMillis: 2000, // Return error after 2 seconds if connection fails
    });

    // Handle pool errors
    this.pool.on('error', (err) => {
      console.error('❌ Unexpected database error:', err);
    });

    // Test connection on initialization
    this.testConnection();
  }

  /**
   * Get singleton instance
   */
  public static getInstance(): Database {
    if (!Database.instance) {
      Database.instance = new Database();
    }
    return Database.instance;
  }

  /**
   * Test database connection
   */
  private async testConnection(): Promise<void> {
    try {
      const client = await this.pool.connect();
      const result = await client.query('SELECT NOW()');
      console.log('✅ Database connected at:', result.rows[0].now);
      client.release();
    } catch (error) {
      console.error('❌ Database connection failed:', error);
      throw error;
    }
  }

  /**
   * Execute a query
   */
  public async query<T extends QueryResultRow = any>(text: string, params?: any[]): Promise<QueryResult<T>> {
    const start = Date.now();
    try {
      const result = await this.pool.query<T>(text, params);
      const duration = Date.now() - start;
      if (duration > 1000) {
        console.warn(`⚠️ Slow query (${duration}ms):`, text.substring(0, 100));
      }
      return result;
    } catch (error) {
      console.error('❌ Query error:', text, error);
      throw error;
    }
  }

  /**
   * Get a client from the pool (for transactions)
   */
  public async getClient(): Promise<PoolClient> {
    return this.pool.connect();
  }

  /**
   * Execute a transaction
   */
  public async transaction<T>(
    callback: (client: PoolClient) => Promise<T>
  ): Promise<T> {
    const client = await this.getClient();
    try {
      await client.query('BEGIN');
      const result = await callback(client);
      await client.query('COMMIT');
      return result;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Close all connections
   */
  public async close(): Promise<void> {
    await this.pool.end();
    console.log('📁 Database connections closed');
  }

  /**
   * Get pool statistics
   */
  public getStats() {
    return {
      totalCount: this.pool.totalCount,
      idleCount: this.pool.idleCount,
      waitingCount: this.pool.waitingCount,
    };
  }
}

export const db = Database.getInstance();
