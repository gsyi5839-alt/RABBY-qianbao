import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../config';
import type { AuthPayload } from '@rabby/shared';

export type { AuthPayload };

declare global {
  namespace Express {
    interface Request {
      user?: AuthPayload;
    }
  }
}

export function authRequired(req: Request, res: Response, next: NextFunction): void {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    res.status(401).json({ error: { message: 'Authorization token required', status: 401 } });
    return;
  }

  const token = header.slice(7);
  try {
    const payload = jwt.verify(token, config.jwtSecret) as AuthPayload;
    req.user = payload;
    next();
  } catch {
    res.status(401).json({ error: { message: 'Invalid or expired token', status: 401 } });
  }
}

export function adminRequired(req: Request, res: Response, next: NextFunction): void {
  authRequired(req, res, () => {
    if (req.user?.role !== 'admin') {
      res.status(403).json({ error: { message: 'Admin access required', status: 403 } });
      return;
    }
    next();
  });
}

export function generateTokens(payload: AuthPayload) {
  const accessToken = jwt.sign(payload, config.jwtSecret, {
    expiresIn: config.jwtExpiresIn as jwt.SignOptions['expiresIn'],
  });
  const refreshToken = jwt.sign({ ...payload, type: 'refresh' }, config.jwtSecret, {
    expiresIn: config.jwtRefreshExpiresIn as jwt.SignOptions['expiresIn'],
  });
  return { accessToken, refreshToken };
}
