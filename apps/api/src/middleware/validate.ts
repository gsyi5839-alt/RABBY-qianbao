import { Request, Response, NextFunction } from 'express';

const ETH_ADDRESS_RE = /^0x[0-9a-fA-F]{40}$/;

export function validateAddress(paramName = 'address') {
  return (req: Request, res: Response, next: NextFunction): void => {
    const address = String(req.params[paramName] || '');
    if (!address || !ETH_ADDRESS_RE.test(address)) {
      res.status(400).json({
        error: { message: `Invalid Ethereum address: ${address}`, status: 400 },
      });
      return;
    }
    next();
  };
}

export function requireQuery(...keys: string[]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const missing = keys.filter((k) => !req.query[k]);
    if (missing.length > 0) {
      res.status(400).json({
        error: { message: `Missing required query parameters: ${missing.join(', ')}`, status: 400 },
      });
      return;
    }
    next();
  };
}

export function requireBody(...keys: string[]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const missing = keys.filter((k) => !(k in (req.body || {})));
    if (missing.length > 0) {
      res.status(400).json({
        error: { message: `Missing required body fields: ${missing.join(', ')}`, status: 400 },
      });
      return;
    }
    next();
  };
}
