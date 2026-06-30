import { RequestHandler } from 'express';
import { Errors } from '../utils/errors';

/** Requires an authenticated admin (use after `authGuard`). */
export const adminGuard: RequestHandler = (req, _res, next) => {
  if (!req.auth) return next(Errors.unauthorized());
  if (req.auth.role !== 'admin') return next(Errors.forbidden('Admin access required', 'ADMIN_ONLY'));
  next();
};
