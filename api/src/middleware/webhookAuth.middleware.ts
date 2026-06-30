import { RequestHandler } from 'express';
import { Errors } from '../utils/errors';

/**
 * Authenticates RevenueCat webhooks via a shared secret in the Authorization header
 * (configured in the RevenueCat dashboard). Reads the secret at request time so it
 * is easy to configure per environment. Rejects if unset or mismatched.
 */
export const webhookAuth: RequestHandler = (req, _res, next) => {
  const secret = process.env.REVENUECAT_WEBHOOK_SECRET;
  if (!secret) return next(Errors.internal('Webhook secret not configured'));
  const header = req.headers.authorization;
  const expected = `Bearer ${secret}`;
  if (header !== expected && header !== secret) {
    return next(Errors.unauthorized('Invalid webhook signature'));
  }
  next();
};
