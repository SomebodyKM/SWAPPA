import { Router } from 'express';
import { z } from 'zod';
import { skillController } from '../controllers/skill.controller';
import { authGuard } from '../middleware/auth.middleware';
import { validate } from '../middleware/validate.middleware';

const router = Router();

const browseQuery = z.object({
  query: z.string().max(80).optional(),
  all: z.coerce.boolean().optional(),
});
const idParam = z.object({ id: z.string().length(24) });

router.get('/', authGuard, validate({ query: browseQuery }), skillController.browse);
router.get('/categories', authGuard, skillController.categories);
router.get('/:id', authGuard, validate({ params: idParam }), skillController.read);

// Catalog mutation (create/edit/delete) is admin-only — see /admin/skills (US9, FR-040).

export default router;
