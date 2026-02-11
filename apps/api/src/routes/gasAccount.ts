import { Router, Request, Response, NextFunction } from 'express';
import { rabbyApi } from '../services/rabbyApi';

const router = Router();

router.get('/api/gas-account/info', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const response = await rabbyApi.get('/v1/gas_account/info', {
      params: req.query,
    });
    res.json(response.data);
  } catch (err) {
    next(err);
  }
});

router.get('/api/gas-account/history', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const response = await rabbyApi.get('/v1/gas_account/history', {
      params: req.query,
    });
    res.json(response.data);
  } catch (err) {
    next(err);
  }
});

router.get('/api/gas-account/:address', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const address = String(req.params.address);
    const response = await rabbyApi.get('/v1/gas_account/info', {
      params: { address },
    });
    res.json(response.data);
  } catch (err) {
    next(err);
  }
});

export default router;
