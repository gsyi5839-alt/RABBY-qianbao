import { Router, Request, Response, NextFunction } from 'express';
import { rabbyApi } from '../services/rabbyApi';
import { cache } from '../services/cache';

const router = Router();

const CACHE_KEY = 'chains:list';
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes

router.get('/api/chains/list', async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const cached = cache.get<unknown>(CACHE_KEY);
    if (cached) {
      res.json(cached);
      return;
    }
    const response = await rabbyApi.get('/v1/chain/list');
    cache.set(CACHE_KEY, response.data, CACHE_TTL);
    res.json(response.data);
  } catch (err) {
    next(err);
  }
});

export default router;
