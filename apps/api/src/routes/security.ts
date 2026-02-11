import { Router, Request, Response, NextFunction } from 'express';
import { rabbyApi } from '../services/rabbyApi';
import { validateAddress } from '../middleware/validate';
import { adminRequired } from '../middleware/auth';
import { securityStore } from '../services/securityStore';

const router = Router();

// Check address risk (contract / EOA / phishing)
router.get('/api/security/address/:address', validateAddress(), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const address = String(req.params.address);
    const chainId = String(req.query.chain_id || '');
    const response = await rabbyApi.get('/v1/user/addr', {
      params: { id: address, ...(chainId ? { chain_id: chainId } : {}) },
    });
    res.json(response.data);
  } catch (err) {
    next(err);
  }
});

// Check token risk
router.get('/api/security/token', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { chain_id, token_id } = req.query;
    if (!chain_id || !token_id) {
      res.status(400).json({ error: { message: 'chain_id and token_id are required', status: 400 } });
      return;
    }
    const response = await rabbyApi.get('/v1/token', {
      params: { chain_id, id: token_id },
    });
    res.json(response.data);
  } catch (err) {
    next(err);
  }
});

// Check contract interaction risk
router.get('/api/security/contract', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { chain_id, contract_id } = req.query;
    if (!chain_id || !contract_id) {
      res.status(400).json({ error: { message: 'chain_id and contract_id are required', status: 400 } });
      return;
    }
    const response = await rabbyApi.get('/v1/contract', {
      params: { chain_id, id: contract_id },
    });
    res.json(response.data);
  } catch (err) {
    next(err);
  }
});

// ===== Admin-managed security datasets =====

router.get('/api/security/rules', adminRequired, (_req: Request, res: Response) => {
  res.json({ list: securityStore.listRules() });
});

router.post('/api/security/rules', adminRequired, (req: Request, res: Response) => {
  const { name, description, type, severity, enabled, triggers, lastTriggered } = req.body || {};
  if (!name || !description || !type) {
    res.status(400).json({ error: { message: 'name, description, and type are required', status: 400 } });
    return;
  }
  const rule = securityStore.createRule({
    name,
    description,
    type,
    severity: securityStore.normalizeSeverity(severity),
    enabled: enabled !== false,
    triggers: typeof triggers === 'number' ? triggers : 0,
    lastTriggered: lastTriggered || undefined,
  });
  res.status(201).json(rule);
});

router.put('/api/security/rules/:id', adminRequired, (req: Request, res: Response) => {
  const { severity } = req.body || {};
  const updated = securityStore.updateRule(String(req.params.id), {
    ...req.body,
    ...(severity ? { severity: securityStore.normalizeSeverity(severity) } : {}),
  });
  if (!updated) {
    res.status(404).json({ error: { message: 'Rule not found', status: 404 } });
    return;
  }
  res.json(updated);
});

router.delete('/api/security/rules/:id', adminRequired, (req: Request, res: Response) => {
  const ok = securityStore.deleteRule(String(req.params.id));
  if (!ok) {
    res.status(404).json({ error: { message: 'Rule not found', status: 404 } });
    return;
  }
  res.json({ success: true });
});

router.get('/api/security/phishing', adminRequired, (_req: Request, res: Response) => {
  res.json({ list: securityStore.listPhishing() });
});

router.post('/api/security/phishing', adminRequired, (req: Request, res: Response) => {
  const { address, domain, type, reportedBy, status, addedDate } = req.body || {};
  if (!address || !domain || !type) {
    res.status(400).json({ error: { message: 'address, domain, and type are required', status: 400 } });
    return;
  }
  const entry = securityStore.createPhishing({
    address,
    domain,
    type,
    reportedBy: reportedBy || 'manual',
    status: securityStore.normalizeStatus(status),
    addedDate: addedDate || securityStore.nowDate(),
  });
  res.status(201).json(entry);
});

router.put('/api/security/phishing/:id', adminRequired, (req: Request, res: Response) => {
  const { status } = req.body || {};
  const updated = securityStore.updatePhishing(String(req.params.id), {
    ...req.body,
    ...(status ? { status: securityStore.normalizeStatus(status) } : {}),
  });
  if (!updated) {
    res.status(404).json({ error: { message: 'Phishing entry not found', status: 404 } });
    return;
  }
  res.json(updated);
});

router.delete('/api/security/phishing/:id', adminRequired, (req: Request, res: Response) => {
  const ok = securityStore.deletePhishing(String(req.params.id));
  if (!ok) {
    res.status(404).json({ error: { message: 'Phishing entry not found', status: 404 } });
    return;
  }
  res.json({ success: true });
});

router.get('/api/security/contracts', adminRequired, (_req: Request, res: Response) => {
  res.json({ list: securityStore.listContracts() });
});

router.post('/api/security/contracts', adminRequired, (req: Request, res: Response) => {
  const { address, name, chainId, status, addedDate } = req.body || {};
  if (!address) {
    res.status(400).json({ error: { message: 'address is required', status: 400 } });
    return;
  }
  const entry = securityStore.createContract({
    address,
    name,
    chainId,
    status: securityStore.normalizeContractStatus(status),
    addedDate: addedDate || securityStore.nowDate(),
  });
  res.status(201).json(entry);
});

router.put('/api/security/contracts/:id', adminRequired, (req: Request, res: Response) => {
  const { status } = req.body || {};
  const updated = securityStore.updateContract(String(req.params.id), {
    ...req.body,
    ...(status ? { status: securityStore.normalizeContractStatus(status) } : {}),
  });
  if (!updated) {
    res.status(404).json({ error: { message: 'Contract not found', status: 404 } });
    return;
  }
  res.json(updated);
});

router.delete('/api/security/contracts/:id', adminRequired, (req: Request, res: Response) => {
  const ok = securityStore.deleteContract(String(req.params.id));
  if (!ok) {
    res.status(404).json({ error: { message: 'Contract not found', status: 404 } });
    return;
  }
  res.json({ success: true });
});

router.get('/api/security/alerts', adminRequired, (_req: Request, res: Response) => {
  res.json({ list: securityStore.listAlerts() });
});

router.post('/api/security/alerts', adminRequired, (req: Request, res: Response) => {
  const { title, level, status, createdAt, description } = req.body || {};
  if (!title) {
    res.status(400).json({ error: { message: 'title is required', status: 400 } });
    return;
  }
  const alert = securityStore.createAlert({
    title,
    level: securityStore.normalizeSeverity(level),
    status: securityStore.normalizeAlertStatus(status),
    createdAt: createdAt || securityStore.nowDateTime(),
    description,
  });
  res.status(201).json(alert);
});

router.put('/api/security/alerts/:id', adminRequired, (req: Request, res: Response) => {
  const { level, status } = req.body || {};
  const updated = securityStore.updateAlert(String(req.params.id), {
    ...req.body,
    ...(level ? { level: securityStore.normalizeSeverity(level) } : {}),
    ...(status ? { status: securityStore.normalizeAlertStatus(status) } : {}),
  });
  if (!updated) {
    res.status(404).json({ error: { message: 'Alert not found', status: 404 } });
    return;
  }
  res.json(updated);
});

router.delete('/api/security/alerts/:id', adminRequired, (req: Request, res: Response) => {
  const ok = securityStore.deleteAlert(String(req.params.id));
  if (!ok) {
    res.status(404).json({ error: { message: 'Alert not found', status: 404 } });
    return;
  }
  res.json({ success: true });
});

// Whitelist management (in-memory)
const whitelist = new Set<string>();

router.get('/api/security/whitelist', adminRequired, (_req: Request, res: Response) => {
  res.json({ addresses: Array.from(whitelist) });
});

router.post('/api/security/whitelist', adminRequired, (req: Request, res: Response) => {
  const { address } = req.body || {};
  if (!address || !/^0x[0-9a-fA-F]{40}$/.test(address)) {
    res.status(400).json({ error: { message: 'Valid Ethereum address required', status: 400 } });
    return;
  }
  whitelist.add(address.toLowerCase());
  res.json({ success: true, addresses: Array.from(whitelist) });
});

router.delete('/api/security/whitelist/:address', adminRequired, (req: Request, res: Response) => {
  const address = String(req.params.address || '').toLowerCase();
  whitelist.delete(address);
  res.json({ success: true, addresses: Array.from(whitelist) });
});

export default router;
