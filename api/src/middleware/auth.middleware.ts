import { RequestHandler } from 'express';
import { verifyAccessToken } from '../utils/jwt';
import { User } from '../models/user.model';
import { Errors } from '../utils/errors';

/**
 * Authenticates the request via Bearer JWT, loads the user, and rejects
 * suspended/banned accounts (Constitution VI). Attaches `req.auth` + `req.currentUser`.
 */
export const authGuard: RequestHandler = async (req, _res, next) => {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return next(Errors.unauthorized('Missing bearer token'));
  }
  const token = header.slice('Bearer '.length).trim();

  let payload;
  try {
    payload = verifyAccessToken(token);
  } catch {
    return next(Errors.unauthorized('Invalid or expired token'));
  }

  const user = await User.findById(payload.sub).select('+passwordHash');
  if (!user) return next(Errors.unauthorized('Account not found'));
  if (user.status !== 'active') {
    return next(Errors.forbidden('Account is not active', 'ACCOUNT_INACTIVE', { status: user.status }));
  }

  req.auth = { userId: String(user._id), role: user.role };
  req.currentUser = user;
  next();
};
