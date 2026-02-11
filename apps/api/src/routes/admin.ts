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

router.get('/api/admin/dapps', adminRequired, (req: Request, res: Response) => {
  const includeDisabled = String(req.query.all || '') === 'true';
  res.json({ list: adminStore.listDapps(includeDisabled) });
});

router.post('/api/admin/dapps', adminRequired, (req: Request, res: Response, next: NextFunction) => {
  try {
    const { name, url, icon, category, enabled = true, order = 0 } = req.body || {};
    if (!name || !url) {
      res.status(400).json({ error: { message: 'name and url are required', status: 400 } });
      return;
    }
    const dapp = adminStore.createDapp({ name, url, icon: icon || '', category: category || '', enabled, order });
    res.status(201).json(dapp);
  } catch (err) {
    next(err);
  }
});

router.put('/api/admin/dapps/:id', adminRequired, (req: Request, res: Response) => {
  const updated = adminStore.updateDapp(String(req.params.id), req.body);
  if (!updated) {
    res.status(404).json({ error: { message: 'Dapp not found', status: 404 } });
    return;
  }
  res.json(updated);
});

router.delete('/api/admin/dapps/:id', adminRequired, (req: Request, res: Response) => {
  const ok = adminStore.deleteDapp(String(req.params.id));
  if (!ok) {
    res.status(404).json({ error: { message: 'Dapp not found', status: 404 } });
    return;
  }
  res.json({ success: true });
});

// ===== Chains CRUD =====

router.get('/api/admin/chains', adminRequired, (req: Request, res: Response) => {
  const includeDisabled = String(req.query.all || '') === 'true';
  res.json({ list: adminStore.listChains(includeDisabled) });
});

router.post('/api/admin/chains', adminRequired, (req: Request, res: Response, next: NextFunction) => {
  try {
    const { chainId, name, nativeCurrency, rpcUrl, explorerUrl, enabled = true, order = 0 } = req.body || {};
    if (!chainId || !name || !rpcUrl) {
      res.status(400).json({ error: { message: 'chainId, name, and rpcUrl are required', status: 400 } });
      return;
    }
    const chain = adminStore.createChain({
      chainId,
      name,
      nativeCurrency: nativeCurrency || { name: 'ETH', symbol: 'ETH', decimals: 18 },
      rpcUrl,
      explorerUrl: explorerUrl || '',
      enabled,
      order,
    });
    res.status(201).json(chain);
  } catch (err) {
    next(err);
  }
});

router.put('/api/admin/chains/:id', adminRequired, (req: Request, res: Response) => {
  const updated = adminStore.updateChain(String(req.params.id), req.body);
  if (!updated) {
    res.status(404).json({ error: { message: 'Chain not found', status: 404 } });
    return;
  }
  res.json(updated);
});

router.delete('/api/admin/chains/:id', adminRequired, (req: Request, res: Response) => {
  const ok = adminStore.deleteChain(String(req.params.id));
  if (!ok) {
    res.status(404).json({ error: { message: 'Chain not found', status: 404 } });
    return;
  }
  res.json({ success: true });
});

// ===== Stats =====

router.get('/api/admin/stats', adminRequired, (_req: Request, res: Response) => {
  const users = userStore.getAll();
  const totalUsers = userStore.count();
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
});

export default router;
