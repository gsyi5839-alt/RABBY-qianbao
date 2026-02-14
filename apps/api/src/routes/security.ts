import { Router, Request, Response, NextFunction } from 'express';
import { rabbyApi } from '../services/rabbyApi';
import { validateAddress } from '../middleware/validate';
import { adminRequired } from '../middleware/auth';
import { securityStore } from '../services/securityStore';
import type { SecuritySeverity, SecurityStatus, ContractStatus, AlertStatus } from '@rabby/shared';

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

// Helper functions to normalize values
const normalizeSeverity = (val: any): SecuritySeverity => {
  const normalized = String(val || 'medium').toLowerCase();
  if (['low', 'medium', 'high', 'critical'].includes(normalized)) {
    return normalized as SecuritySeverity;
  }
  return 'medium';
};

const normalizeStatus = (val: any): SecurityStatus => {
  const normalized = String(val || 'pending').toLowerCase();
  if (['confirmed', 'pending'].includes(normalized)) {
    return normalized as SecurityStatus;
  }
  return 'pending';
};

const normalizeContractStatus = (val: any): ContractStatus => {
  const normalized = String(val || 'active').toLowerCase();
  if (['active', 'disabled'].includes(normalized)) {
    return normalized as ContractStatus;
  }
  return 'active';
};

const normalizeAlertStatus = (val: any): AlertStatus => {
  const normalized = String(val || 'open').toLowerCase();
  if (['open', 'resolved'].includes(normalized)) {
    return normalized as AlertStatus;
  }
  return 'open';
};

router.get('/api/security/rules', adminRequired, async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const list = await securityStore.listRules();
    res.json({ list });
  } catch (err) {
    next(err);
  }
});

router.post('/api/security/rules', adminRequired, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { name, description, type, severity, enabled, triggers, lastTriggered } = req.body || {};
    if (!name || !type) {
      res.status(400).json({ error: { message: 'name and type are required', status: 400 } });
      return;
    }
    const rule = await securityStore.createRule({
      name,
      description,
      type,
      severity: normalizeSeverity(severity),
      enabled: enabled !== false,
      triggers: typeof triggers === 'number' ? triggers : 0,
      lastTriggered: lastTriggered || undefined,
    });
    res.status(201).json(rule);
  } catch (err) {
    next(err);
  }
});

router.put('/api/security/rules/:id', adminRequired, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { severity, ...rest } = req.body || {};
    const updated = await securityStore.updateRule(String(req.params.id), {
      ...rest,
      ...(severity ? { severity: normalizeSeverity(severity) } : {}),
    });
    if (!updated) {
      res.status(404).json({ error: { message: 'Rule not found', status: 404 } });
      return;
    }
    res.json(updated);
  } catch (err) {
    next(err);
  }
});

router.delete('/api/security/rules/:id', adminRequired, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const ok = await securityStore.deleteRule(String(req.params.id));
    if (!ok) {
      res.status(404).json({ error: { message: 'Rule not found', status: 404 } });
      return;
    }
    res.json({ success: true });
  } catch (err) {
    next(err);
  }
});

router.get('/api/security/phishing', adminRequired, async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const list = await securityStore.listPhishing();
    res.json({ list });
  } catch (err) {
    next(err);
  }
});

router.post('/api/security/phishing', adminRequired, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { address, domain, type, reportedBy, status, addedDate } = req.body || {};
    if (!address || !domain || !type) {
      res.status(400).json({ error: { message: 'address, domain, and type are required', status: 400 } });
      return;
    }
    const entry = await securityStore.createPhishing({
      address,
      domain,
      type,
      reportedBy: reportedBy || 'manual',
      status: normalizeStatus(status),
      addedDate: addedDate || new Date().toISOString().slice(0, 10),
    });
    res.status(201).json(entry);
  } catch (err) {
    next(err);
  }
});

router.put('/api/security/phishing/:id', adminRequired, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { status, ...rest } = req.body || {};
    const updated = await securityStore.updatePhishing(String(req.params.id), {
      ...rest,
      ...(status ? { status: normalizeStatus(status) } : {}),
    });
    if (!updated) {
      res.status(404).json({ error: { message: 'Phishing entry not found', status: 404 } });
      return;
    }
    res.json(updated);
  } catch (err) {
    next(err);
  }
});

router.delete('/api/security/phishing/:id', adminRequired, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const ok = await securityStore.deletePhishing(String(req.params.id));
    if (!ok) {
      res.status(404).json({ error: { message: 'Phishing entry not found', status: 404 } });
      return;
    }
    res.json({ success: true });
  } catch (err) {
    next(err);
  }
});

router.get('/api/security/contracts', adminRequired, async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const list = await securityStore.listContracts();
    res.json({ list });
  } catch (err) {
    next(err);
  }
});

router.post('/api/security/contracts', adminRequired, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { address, name, chainId, status, addedDate } = req.body || {};
    if (!address) {
      res.status(400).json({ error: { message: 'address is required', status: 400 } });
      return;
    }
    const entry = await securityStore.createContract({
      address,
      name,
      chainId,
      status: normalizeContractStatus(status),
      addedDate: addedDate || new Date().toISOString().slice(0, 10),
    });
    res.status(201).json(entry);
  } catch (err) {
    next(err);
  }
});

router.put('/api/security/contracts/:id', adminRequired, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { status, ...rest } = req.body || {};
    const updated = await securityStore.updateContract(String(req.params.id), {
      ...rest,
      ...(status ? { status: normalizeContractStatus(status) } : {}),
    });
    if (!updated) {
      res.status(404).json({ error: { message: 'Contract not found', status: 404 } });
      return;
    }
    res.json(updated);
  } catch (err) {
    next(err);
  }
});

router.delete('/api/security/contracts/:id', adminRequired, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const ok = await securityStore.deleteContract(String(req.params.id));
    if (!ok) {
      res.status(404).json({ error: { message: 'Contract not found', status: 404 } });
      return;
    }
    res.json({ success: true });
  } catch (err) {
    next(err);
  }
});

router.get('/api/security/alerts', adminRequired, async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const list = await securityStore.listAlerts();
    res.json({ list });
  } catch (err) {
    next(err);
  }
});

router.post('/api/security/alerts', adminRequired, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { title, level, status, createdAt, description } = req.body || {};
    if (!title) {
      res.status(400).json({ error: { message: 'title is required', status: 400 } });
      return;
    }
    const alert = await securityStore.createAlert({
      title,
      level: normalizeSeverity(level),
      status: normalizeAlertStatus(status),
      createdAt: createdAt || new Date().toISOString().replace('T', ' ').slice(0, 16),
      description,
    });
    res.status(201).json(alert);
  } catch (err) {
    next(err);
  }
});

router.put('/api/security/alerts/:id', adminRequired, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { level, status, ...rest } = req.body || {};
    const updated = await securityStore.updateAlert(String(req.params.id), {
      ...rest,
      ...(level ? { level: normalizeSeverity(level) } : {}),
      ...(status ? { status: normalizeAlertStatus(status) } : {}),
    });
    if (!updated) {
      res.status(404).json({ error: { message: 'Alert not found', status: 404 } });
      return;
    }
    res.json(updated);
  } catch (err) {
    next(err);
  }
});

router.delete('/api/security/alerts/:id', adminRequired, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const ok = await securityStore.deleteAlert(String(req.params.id));
    if (!ok) {
      res.status(404).json({ error: { message: 'Alert not found', status: 404 } });
      return;
    }
    res.json({ success: true });
  } catch (err) {
    next(err);
  }
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
