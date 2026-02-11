import { Router, Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../config';
import { userStore, nonceStore } from '../services/userStore';
import { authRequired, generateTokens, AuthPayload } from '../middleware/auth';
import { authLimiter } from '../middleware/rateLimiter';

const router = Router();

// Get a nonce for signing
router.get('/api/auth/nonce', authLimiter, (req: Request, res: Response) => {
  const address = String(req.query.address || '').toLowerCase();
  if (!address || !/^0x[0-9a-fA-F]{40}$/.test(address)) {
    res.status(400).json({ error: { message: 'Valid Ethereum address required', status: 400 } });
    return;
  }
  const nonce = nonceStore.generate(address);
  res.json({ nonce, message: `Sign this message to login to Rabby:\n\nNonce: ${nonce}` });
});

// Verify signature and issue JWT
// In production, use ethers.verifyMessage() to verify the signature.
// For now, accept { address, nonce, signature } and verify the nonce only.
router.post('/api/auth/verify', authLimiter, (req: Request, res: Response, next: NextFunction) => {
  try {
    const { address, nonce, signature } = req.body || {};
    if (!address || !nonce) {
      res.status(400).json({ error: { message: 'address and nonce are required', status: 400 } });
      return;
    }

    const lower = String(address).toLowerCase();
    if (!nonceStore.verify(lower, nonce)) {
      res.status(401).json({ error: { message: 'Invalid or expired nonce', status: 401 } });
      return;
    }

    // TODO: In production, verify `signature` against the nonce message using ethers.verifyMessage()
    // For dev: if signature is provided, we trust it; if not, still allow (dev mode only)
    if (!signature && process.env.NODE_ENV === 'production') {
      res.status(400).json({ error: { message: 'Signature required', status: 400 } });
      return;
    }

    // Create or get user
    const user = userStore.create(lower);
    const payload: AuthPayload = { userId: user.id, address: user.address, role: user.role };
    const tokens = generateTokens(payload);

    res.json({
      user: { id: user.id, address: user.address, addresses: user.addresses, role: user.role },
      ...tokens,
    });
  } catch (err) {
    next(err);
  }
});

// Refresh token
router.post('/api/auth/refresh', authLimiter, (req: Request, res: Response, next: NextFunction) => {
  try {
    const { refreshToken } = req.body || {};
    if (!refreshToken) {
      res.status(400).json({ error: { message: 'refreshToken is required', status: 400 } });
      return;
    }

    const decoded = jwt.verify(refreshToken, config.jwtSecret) as AuthPayload & { type?: string };
    if (decoded.type !== 'refresh') {
      res.status(401).json({ error: { message: 'Invalid refresh token', status: 401 } });
      return;
    }

    const user = userStore.findById(decoded.userId);
    if (!user) {
      res.status(401).json({ error: { message: 'User not found', status: 401 } });
      return;
    }

    const payload: AuthPayload = { userId: user.id, address: user.address, role: user.role };
    const tokens = generateTokens(payload);
    res.json(tokens);
  } catch {
    res.status(401).json({ error: { message: 'Invalid or expired refresh token', status: 401 } });
  }
});

// Get current user
router.get('/api/auth/me', authRequired, (req: Request, res: Response) => {
  const user = userStore.findById(req.user!.userId);
  if (!user) {
    res.status(404).json({ error: { message: 'User not found', status: 404 } });
    return;
  }
  res.json({
    id: user.id,
    address: user.address,
    addresses: user.addresses,
    role: user.role,
    createdAt: user.createdAt,
  });
});

export default router;
