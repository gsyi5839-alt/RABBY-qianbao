import express from 'express';
import { config } from './config';
import { corsMiddleware } from './middleware/cors';
import { globalLimiter } from './middleware/rateLimiter';
import { requestLogger } from './middleware/requestLogger';
import { errorHandler } from './middleware/errorHandler';
import routes from './routes';
import { db } from './services/database';

const app = express();

app.use(express.json());
app.use(corsMiddleware);
app.use(globalLimiter);
app.use(requestLogger);

// Health check (with database status)
app.get('/health', async (_req, res) => {
  try {
    const stats = db.getStats();
    const result = await db.query('SELECT NOW()');
    res.json({
      status: 'ok',
      timestamp: new Date().toISOString(),
      database: {
        connected: true,
        serverTime: result.rows[0].now,
        pool: stats,
      },
    });
  } catch (error) {
    res.status(503).json({
      status: 'error',
      timestamp: new Date().toISOString(),
      database: { connected: false, error: (error as Error).message },
    });
  }
});

// Backwards-compatible chains config endpoint (both paths)
app.get(['/chains/config', '/api/chains/config'], (_req, res) => {
  res.json({ apiUrl: config.rabbyApiUrl, supported: true });
});

// All API routes
app.use(routes);

// Error handler (must be registered last)
app.use(errorHandler);

const PORT = config.port;

app.listen(PORT, () => {
  console.log(`
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║   🚀  Rabby API Server Started                                ║
║                                                                ║
║   📍  Server:    http://localhost:${PORT}                          ║
║   🗄️   Database:  PostgreSQL (${config.database.host}:${config.database.port})          ║
║   📊  Health:    http://localhost:${PORT}/health                   ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
  `);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('⏹️  SIGTERM received, shutting down gracefully...');
  await db.close();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('⏹️  SIGINT received, shutting down gracefully...');
  await db.close();
  process.exit(0);
});
