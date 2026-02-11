import { Router, Request, Response } from 'express';
import { adminStore } from '../services/adminStore';

const router = Router();

router.get('/api/dapps/list', (req: Request, res: Response) => {
  const { q } = req.query;
  let list = adminStore.listDapps();
  if (q) {
    const query = String(q).toLowerCase();
    list = list.filter((d) => d.name.toLowerCase().includes(query));
  }
  res.json({ list });
});

export default router;
