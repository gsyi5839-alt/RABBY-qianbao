import { Request, Response, NextFunction } from 'express';

interface ApiError extends Error {
  status?: number;
}

export function errorHandler(
  err: ApiError,
  _req: Request,
  res: Response,
  _next: NextFunction
): void {
  const status = err.status || 500;
  res.status(status).json({
    error: {
      message: err.message || 'Internal Server Error',
      status,
    },
  });
}
