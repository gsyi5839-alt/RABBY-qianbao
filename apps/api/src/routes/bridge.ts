import { Router, Request, Response, NextFunction } from 'express';
import { rabbyApi } from '../services/rabbyApi';
import { requireBody } from '../middleware/validate';

const router = Router();

router.get('/api/bridge/quotes', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const response = await rabbyApi.get('/v1/bridge/quote', {
      params: req.query,
    });
    res.json(response.data);
  } catch (err) {
    next(err);
  }
});

router.post('/api/bridge/build', requireBody('bridge_id', 'from_chain_id', 'to_chain_id', 'from_token', 'to_token', 'amount', 'from_address'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const response = await rabbyApi.post('/v1/bridge/build', req.body);
    res.json(response.data);
  } catch (err) {
    next(err);
  }
});

export default router;
