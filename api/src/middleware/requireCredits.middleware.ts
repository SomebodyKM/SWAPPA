import { RequestHandler } from 'express';
import { AiAction, AI_ACTION_COST } from '../config/limits';
import { creditService } from '../services/credit.service';
import { Errors } from '../utils/errors';

/**
 * Pre-checks that the user can afford an AI action before it runs (FR-016).
 * Attaches the resolved cost to `res.locals.creditCost`. The actual deduction
 * happens only on successful generation (FR-017), in the controller via creditService.spend.
 */
export function requireCredits(action: AiAction): RequestHandler {
  return async (req, res, next) => {
    const cost = AI_ACTION_COST[action];
    const available = await creditService.availableCredits(req.auth!.userId);
    if (available < cost) {
      return next(
        Errors.paymentRequired('Insufficient credits for this action', {
          action,
          required: cost,
          available,
          upgrade: 'Buy a Boost pack or upgrade to Premium',
        }),
      );
    }
    res.locals.creditCost = cost;
    next();
  };
}
