import { Router, Request, Response, NextFunction } from 'express';
import { rabbyApi } from '../services/rabbyApi';
import { validateAddress } from '../middleware/validate';

const router = Router();

router.get('/api/tokens/:address', validateAddress(), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const address = String(req.params.address);
    const response = await rabbyApi.get('/v1/user/token_list', {
      params: { id: address, is_all: true },
    });
    res.json(response.data);
  } catch (err) {
    next(err);
  }
});

export default router;
