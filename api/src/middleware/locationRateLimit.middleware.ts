import { RequestHandler } from 'express';
import { Errors } from '../utils/errors';

const WINDOW_MS = 24 * 60 * 60 * 1000;
const MAX_UPDATES_PER_DAY = 10;

/**
 * Per-user daily cap on location updates (defense against geocoding-quota
 * abuse). In-memory: resets on server restart and isn't shared across
 * instances — an acceptable trade-off at this stage (single dev/staging
 * instance, no Redis yet).
 */
const hits = new Map<string, { count: number; resetAt: number }>();

export const locationUpdateLimiter: RequestHandler = (req, _res, next) => {
  const userId = req.auth!.userId;
  const now = Date.now();
  const entry = hits.get(userId);

  if (!entry || entry.resetAt <= now) {
    hits.set(userId, { count: 1, resetAt: now + WINDOW_MS });
    return next();
  }
  if (entry.count >= MAX_UPDATES_PER_DAY) {
    return next(Errors.forbidden('Too many location updates today — try again tomorrow', 'RATE_LIMITED'));
  }
  entry.count += 1;
  next();
};
