import { Router, Request, Response, NextFunction } from 'express';
import { adminStore } from '../services/adminStore';

const router = Router();

router.get('/api/dapps/list', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { q } = req.query;
    let list = await adminStore.listDapps();
    if (q) {
      const query = String(q).toLowerCase();
      list = list.filter((d) =>
        d.name.toLowerCase().includes(query) ||
        d.category.toLowerCase().includes(query) ||
        (d.description || '').toLowerCase().includes(query) ||
        (d.tags || []).some((tag) => tag.toLowerCase().includes(query)),
      );
    }
    res.json({ list });
  } catch (err) {
    next(err);
  }
});

export default router;
