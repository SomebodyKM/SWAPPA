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
const createBody = z.object({ name: z.string().min(1).max(80), category: z.string().min(1).max(60) });

router.get('/', authGuard, validate({ query: browseQuery }), skillController.browse);
router.get('/categories', authGuard, skillController.categories);
router.get('/:id', authGuard, validate({ params: idParam }), skillController.read);
// Any signed-in user can propose a brand-new skill — it always lands as
// `pending` for admin review, never directly in the approved catalog.
// Editing/deleting/approving is admin-only — see /admin/skills (US9, FR-040).
router.post('/', authGuard, validate({ body: createBody }), skillController.create);

export default router;
