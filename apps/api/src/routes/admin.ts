import { Router, Request, Response, NextFunction } from 'express';
import { adminRequired, generateTokens } from '../middleware/auth';
import { adminStore } from '../services/adminStore';
import { userStore } from '../services/userStore';

const router = Router();

// ===== Admin login (demo) =====

router.post('/api/admin/login', (req: Request, res: Response) => {
  const { username, password } = req.body || {};
  if (!username || !password) {
    res.status(400).json({ error: { message: 'username and password are required', status: 400 } });
    return;
  }
  if (username !== 'admin' || password !== 'admin') {
    res.status(401).json({ error: { message: 'Invalid credentials', status: 401 } });
    return;
  }

  const tokens = generateTokens({ userId: 'admin', address: 'admin', role: 'admin' });
  res.json({ user: { id: 'admin', address: 'admin', role: 'admin' }, ...tokens });
});

// ===== Dapps CRUD =====

router.get('/api/admin/dapps', adminRequired, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const includeDisabled = String(req.query.all || '') === 'true';
    const list = await adminStore.listDapps(includeDisabled);
    res.json({ list });
  } catch (err) {
    next(err);
  }
});

router.post('/api/admin/dapps', adminRequired, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { name, url, icon, category, description, chain, users, volume, status, addedDate, riskLevel, enabled = true, order = 0 } = req.body || {};
    if (!name || !url) {
      res.status(400).json({ error: { message: 'name and url are required', status: 400 } });
      return;
    }
    const dapp = await adminStore.createDapp({
      name,
      url,
      icon: icon || '',
      category: category || 'DeFi',
      description,
      chain,
      users,
      volume,
      status: status || 'approved',
      addedDate,
      riskLevel,
      enabled,
      order
    });
    res.status(201).json(dapp);
  } catch (err) {
    next(err);
  }
});

router.put('/api/admin/dapps/:id', adminRequired, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const updated = await adminStore.updateDapp(String(req.params.id), req.body);
    if (!updated) {
      res.status(404).json({ error: { message: 'Dapp not found', status: 404 } });
      return;
    }
    res.json(updated);
  } catch (err) {
    next(err);
  }
});

router.delete('/api/admin/dapps/:id', adminRequired, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const ok = await adminStore.deleteDapp(String(req.params.id));
    if (!ok) {
      res.status(404).json({ error: { message: 'Dapp not found', status: 404 } });
      return;
    }
    res.json({ success: true });
  } catch (err) {
    next(err);
  }
});

// ===== Chains CRUD =====

router.get('/api/admin/chains', adminRequired, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const includeDisabled = String(req.query.all || '') === 'true';
    const list = await adminStore.listChains(includeDisabled);
    res.json({ list });
  } catch (err) {
    next(err);
  }
});

router.post('/api/admin/chains', adminRequired, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { chainId, name, symbol, rpcUrl, explorerUrl, logo, enabled = true, order = 0 } = req.body || {};
    if (!chainId || !name || !rpcUrl) {
      res.status(400).json({ error: { message: 'chainId, name, and rpcUrl are required', status: 400 } });
      return;
    }
    const chain = await adminStore.createChain({
      chainId,
      name,
      symbol,
      rpcUrl,
      explorerUrl,
      logo,
      enabled,
      order,
    });
    res.status(201).json(chain);
  } catch (err) {
    next(err);
  }
});

router.put('/api/admin/chains/:id', adminRequired, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const updated = await adminStore.updateChain(String(req.params.id), req.body);
    if (!updated) {
      res.status(404).json({ error: { message: 'Chain not found', status: 404 } });
      return;
    }
    res.json(updated);
  } catch (err) {
    next(err);
  }
});

router.delete('/api/admin/chains/:id', adminRequired, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const ok = await adminStore.deleteChain(String(req.params.id));
    if (!ok) {
      res.status(404).json({ error: { message: 'Chain not found', status: 404 } });
      return;
    }
    res.json({ success: true });
  } catch (err) {
    next(err);
  }
});

// ===== Stats =====

router.get('/api/admin/stats', adminRequired, async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const users = await userStore.getAll();
    const totalUsers = await userStore.count();
    const totalAddresses = users.reduce((sum, u) => sum + u.addresses.length, 0);

    // Registration time distribution (by day)
    const registrationByDay: Record<string, number> = {};
    users.forEach((u) => {
      const day = new Date(u.createdAt).toISOString().slice(0, 10);
      registrationByDay[day] = (registrationByDay[day] || 0) + 1;
    });

    res.json({
      totalUsers,
      totalAddresses,
      registrationByDay,
    });
  } catch (err) {
    next(err);
  }
});

export default router;
