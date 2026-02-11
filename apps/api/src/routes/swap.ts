import { Router, Request, Response, NextFunction } from 'express';
import { rabbyApi } from '../services/rabbyApi';
import { requireBody } from '../middleware/validate';

const router = Router();

router.get('/api/swap/quote', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const response = await rabbyApi.get('/v1/swap/quote', {
      params: req.query,
    });
    res.json(response.data);
  } catch (err) {
    next(err);
  }
});

router.post('/api/swap/build', requireBody('dex_id', 'from_token', 'to_token', 'amount', 'chain_id', 'from_address'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const response = await rabbyApi.post('/v1/swap/build', req.body);
    res.json(response.data);
  } catch (err) {
    next(err);
  }
});

export default router;
