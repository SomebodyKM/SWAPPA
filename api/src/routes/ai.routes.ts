import { Router } from 'express';
import { z } from 'zod';
import { aiController } from '../controllers/ai.controller';
import { authGuard } from '../middleware/auth.middleware';
import { requireCredits } from '../middleware/requireCredits.middleware';
import { validate } from '../middleware/validate.middleware';
import { aiLimiter } from '../middleware/rateLimit.middleware';

const router = Router();

const icebreakerBody = z.object({ matchUserId: z.string().length(24) });
const rematchBody = z.object({
  skillId: z.string().length(24).optional(),
  mode: z.enum(['local', 'remote']).optional(),
});

router.post(
  '/icebreaker',
  authGuard,
  aiLimiter,
  validate({ body: icebreakerBody }),
  requireCredits('icebreaker'),
  aiController.icebreaker,
);

router.post('/insight', authGuard, aiLimiter, requireCredits('insight'), aiController.insight);

router.post(
  '/rematch',
  authGuard,
  aiLimiter,
  validate({ body: rematchBody }),
  requireCredits('rematch'),
  aiController.rematch,
);

router.post(
  '/profile-optimizer',
  authGuard,
  aiLimiter,
  requireCredits('profile_opt'),
  aiController.profileOptimizer,
);

export default router;
