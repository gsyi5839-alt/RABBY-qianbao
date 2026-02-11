import { Router, Request, Response, NextFunction } from 'express';
import { rabbyApi } from '../services/rabbyApi';
import { validateAddress } from '../middleware/validate';

const router = Router();

router.get('/api/history/:address', validateAddress(), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const address = String(req.params.address);
    const params: Record<string, string> = {
      id: address,
      start_time: '0',
      page_count: String(req.query.limit || '20'),
    };
    if (req.query.chain_id) {
      params.chain_id = String(req.query.chain_id);
    }
    const response = await rabbyApi.get('/v1/user/history_list', { params });
    res.json(response.data);
  } catch (err) {
    next(err);
  }
});

export default router;
