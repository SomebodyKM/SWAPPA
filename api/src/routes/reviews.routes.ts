import { Router } from 'express';
import { z } from 'zod';
import { reviewController } from '../controllers/review.controller';
import { authGuard } from '../middleware/auth.middleware';
import { validate } from '../middleware/validate.middleware';

const router = Router();

const idParam = z.object({ id: z.string().length(24) });
const editBody = z.object({
  rating: z.number().int().min(1).max(5).optional(),
  comment: z.string().max(1000).optional(),
});

router.get('/:id', authGuard, validate({ params: idParam }), reviewController.read);
router.patch('/:id', authGuard, validate({ params: idParam, body: editBody }), reviewController.edit);
router.delete('/:id', authGuard, validate({ params: idParam }), reviewController.remove);

export default router;
