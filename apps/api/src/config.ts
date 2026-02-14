import dotenv from 'dotenv';
import { INITIAL_OPENAPI_URL } from '@rabby/shared';
dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || '3000', 10),
  rabbyApiUrl: process.env.RABBY_API_URL || INITIAL_OPENAPI_URL,
  corsOrigins: (process.env.CORS_ORIGIN || 'http://localhost:3001,http://localhost:3002')
    .split(',')
    .map((s) => s.trim()),
  jwtSecret: process.env.JWT_SECRET || 'rabby-dev-jwt-secret-change-in-production',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '24h',
  jwtRefreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d',
  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '60000', 10),
    max: parseInt(process.env.RATE_LIMIT_MAX || '100', 10),
  },
  database: {
    host: process.env.DATABASE_HOST || 'localhost',
    port: parseInt(process.env.DATABASE_PORT || '5432', 10),
    name: process.env.DATABASE_NAME || 'rabby_db',
    user: process.env.DATABASE_USER || 'rabby_user',
    password: process.env.DATABASE_PASSWORD || 'rabby_password',
  },
};
