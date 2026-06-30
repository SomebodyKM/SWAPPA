import { Router } from 'express';
import { z } from 'zod';
import { matchingController } from '../controllers/matching.controller';
import { authGuard } from '../middleware/auth.middleware';
import { validate } from '../middleware/validate.middleware';

const router = Router();

const browseQuery = z.object({
  skillId: z.string().length(24).optional(),
  mode: z.enum(['local', 'remote']).optional(),
  radius: z.coerce.number().positive().optional(),
  mutualOnly: z.coerce.boolean().optional(),
});

router.get('/', authGuard, validate({ query: browseQuery }), matchingController.browse);

export default router;
