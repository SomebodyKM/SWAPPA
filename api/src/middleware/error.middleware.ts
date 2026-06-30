import { ErrorRequestHandler, RequestHandler } from 'express';
import { AppError } from '../utils/errors';
import { logger } from '../utils/logger';
import { isProd } from '../config/env';

/** 404 handler for unmatched routes. */
export const notFound: RequestHandler = (req, res) => {
  res.status(404).json({ error: { code: 'NOT_FOUND', message: `Route not found: ${req.path}` } });
};

/** Central error handler (must be registered last, 4 args). */
export const errorHandler: ErrorRequestHandler = (err, _req, res, _next) => {
  if (err instanceof AppError) {
    res
      .status(err.status)
      .json({ error: { code: err.code, message: err.message, details: err.details } });
    return;
  }

  // Mongo duplicate key → 409
  if (err && typeof err === 'object' && (err as { code?: number }).code === 11000) {
    res.status(409).json({
      error: { code: 'DUPLICATE_KEY', message: 'Resource already exists', details: (err as any).keyValue },
    });
    return;
  }

  logger.error('Unhandled error', err);
  res.status(500).json({
    error: {
      code: 'INTERNAL',
      message: isProd ? 'Internal server error' : String((err as Error)?.message ?? err),
    },
  });
};
