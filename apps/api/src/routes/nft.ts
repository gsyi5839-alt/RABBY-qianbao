import { Router, Request, Response, NextFunction } from 'express';
import { rabbyApi } from '../services/rabbyApi';
import { validateAddress } from '../middleware/validate';

const router = Router();

router.get('/api/nft/:address', validateAddress(), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const address = String(req.params.address);
    const response = await rabbyApi.get('/v1/user/collection_list', {
      params: { id: address },
    });
    res.json(response.data);
  } catch (err) {
    next(err);
  }
});

export default router;
