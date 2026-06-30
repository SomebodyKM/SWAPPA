import { RequestHandler } from 'express';
import { Errors } from '../utils/errors';

/** Requires an active Premium subscription (use after `authGuard`). */
export const premiumGate: RequestHandler = (req, _res, next) => {
  if (!req.currentUser) return next(Errors.unauthorized());
  if (req.currentUser.tier !== 'premium') {
    return next(Errors.premiumRequired('This feature requires Premium'));
  }
  next();
};
