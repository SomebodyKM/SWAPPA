import { Router } from 'express';
import { z } from 'zod';
import { swapController } from '../controllers/swap.controller';
import { reviewController } from '../controllers/review.controller';
import { authGuard } from '../middleware/auth.middleware';
import { validate } from '../middleware/validate.middleware';

const router = Router();

const idParam = z.object({ id: z.string().length(24) });
const listQuery = z.object({
  status: z.enum(['requested', 'active', 'completed', 'cancelled', 'abandoned']).optional(),
  partnerId: z.string().length(24).optional(),
});
const createBody = z.object({
  partnerId: z.string().length(24),
  offeredSkillId: z.string().length(24),
  requestedSkillId: z.string().length(24),
});
const editBody = z.object({
  offeredSkillId: z.string().length(24).optional(),
  requestedSkillId: z.string().length(24).optional(),
});
const proposeBody = z.object({
  teacherId: z.string().length(24),
  learnerId: z.string().length(24),
  scheduledAt: z.coerce.date(),
  format: z.enum(['in_person', 'remote']),
});
// `.default({})` so a request sent with no body at all (e.g. no reason to
// give) still validates, instead of failing on a missing body object.
const cancelBody = z.object({ reason: z.string().trim().max(500).optional() }).default({});

router.get('/', authGuard, validate({ query: listQuery }), swapController.list);
router.post('/', authGuard, validate({ body: createBody }), swapController.create);
router.get('/:id', authGuard, validate({ params: idParam }), swapController.read);
router.patch('/:id', authGuard, validate({ params: idParam, body: editBody }), swapController.edit);
router.delete('/:id', authGuard, validate({ params: idParam }), swapController.withdraw);
router.post('/:id/accept', authGuard, validate({ params: idParam }), swapController.accept);
router.post('/:id/cancel', authGuard, validate({ params: idParam, body: cancelBody }), swapController.cancel);
router.post('/:id/finish', authGuard, validate({ params: idParam }), swapController.finish);
router.post('/:id/abandon', authGuard, validate({ params: idParam }), swapController.abandon);
router.post('/:id/sessions', authGuard, validate({ params: idParam, body: proposeBody }), swapController.proposeSession);
router.get('/:id/sessions', authGuard, validate({ params: idParam }), swapController.listSessions);

const reviewBody = z.object({ rating: z.number().int().min(1).max(5), comment: z.string().max(1000).optional() });
router.get('/:id/review', authGuard, validate({ params: idParam }), reviewController.mine);
router.post('/:id/review', authGuard, validate({ params: idParam, body: reviewBody }), reviewController.create);

export default router;
