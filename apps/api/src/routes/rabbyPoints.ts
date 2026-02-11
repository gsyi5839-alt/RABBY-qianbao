import { Router, Request, Response, NextFunction } from 'express';
import { rabbyApi } from '../services/rabbyApi';

const router = Router();

router.get('/api/points/campaigns', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const response = await rabbyApi.get('/v1/points/campaigns');
    res.json(response.data);
  } catch (err) {
    next(err);
  }
});

router.get('/api/points/:address', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const address = String(req.params.address);
    const response = await rabbyApi.get('/v1/points/user', {
      params: { id: address },
    });
    res.json(response.data);
  } catch (err) {
    next(err);
  }
});

export default router;
