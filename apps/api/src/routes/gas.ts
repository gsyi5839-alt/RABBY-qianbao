import { Router, Request, Response, NextFunction } from 'express';
import { rabbyApi } from '../services/rabbyApi';

const router = Router();

router.get('/api/gas/price', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const response = await rabbyApi.get('/v1/wallet/gas_market', {
      params: { chain_id: req.query.chainId },
    });
    const data = response.data;
    // Normalize upstream response to { slow, normal, fast, base_fee }
    if (Array.isArray(data) && data.length >= 3) {
      res.json({
        slow: String(data[0]?.price ?? '0'),
        normal: String(data[1]?.price ?? '0'),
        fast: String(data[2]?.price ?? '0'),
        base_fee: data[0]?.base_fee ? String(data[0].base_fee) : undefined,
      });
    } else {
      res.json(data);
    }
  } catch (err) {
    next(err);
  }
});

export default router;
