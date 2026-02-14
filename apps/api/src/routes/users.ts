import { Router, Request, Response, NextFunction } from 'express';
import { authRequired } from '../middleware/auth';
import { userStore } from '../services/userStore';

const router = Router();

// Get user's addresses
router.get('/api/users/me/addresses', authRequired, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = await userStore.findById(req.user!.userId);
    if (!user) {
      res.status(404).json({ error: { message: 'User not found', status: 404 } });
      return;
    }
    res.json({ addresses: user.addresses, primary: user.address });
  } catch (err) {
    next(err);
  }
});

// Add an address
router.post('/api/users/me/addresses', authRequired, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { address } = req.body || {};
    if (!address || !/^0x[0-9a-fA-F]{40}$/.test(address)) {
      res.status(400).json({ error: { message: 'Valid Ethereum address required', status: 400 } });
      return;
    }

    const ok = await userStore.addAddress(req.user!.userId, address);
    if (!ok) {
      res.status(409).json({ error: { message: 'Address already belongs to another user', status: 409 } });
      return;
    }

    const user = await userStore.findById(req.user!.userId);
    res.json({ addresses: user!.addresses, primary: user!.address });
  } catch (err) {
    next(err);
  }
});

// Remove an address
router.delete('/api/users/me/addresses/:address', authRequired, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const address = String(req.params.address || '');
    if (!address || !/^0x[0-9a-fA-F]{40}$/.test(address)) {
      res.status(400).json({ error: { message: 'Valid Ethereum address required', status: 400 } });
      return;
    }

    const ok = await userStore.removeAddress(req.user!.userId, address);
    if (!ok) {
      res.status(400).json({ error: { message: 'Cannot remove primary address or address not found', status: 400 } });
      return;
    }

    const user = await userStore.findById(req.user!.userId);
    res.json({ addresses: user!.addresses, primary: user!.address });
  } catch (err) {
    next(err);
  }
});

export default router;
