import express from 'express';
import { config } from './config';
import { corsMiddleware } from './middleware/cors';
import { globalLimiter } from './middleware/rateLimiter';
import { requestLogger } from './middleware/requestLogger';
import { errorHandler } from './middleware/errorHandler';
import routes from './routes';

const app = express();

app.use(express.json());
app.use(corsMiddleware);
app.use(globalLimiter);
app.use(requestLogger);

// Health check
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Backwards-compatible chains config endpoint (both paths)
app.get(['/chains/config', '/api/chains/config'], (_req, res) => {
  res.json({ apiUrl: config.rabbyApiUrl, supported: true });
});

// All API routes
app.use(routes);

// Error handler (must be registered last)
app.use(errorHandler);

app.listen(config.port, () => {
  console.log(`Rabby API running on http://localhost:${config.port}`);
});
