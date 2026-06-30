import { Router } from 'express';
import { z } from 'zod';
import { sessionController } from '../controllers/session.controller';
import { authGuard } from '../middleware/auth.middleware';
import { validate } from '../middleware/validate.middleware';

const router = Router();

const idParam = z.object({ id: z.string().length(24) });
const listQuery = z.object({ when: z.enum(['upcoming', 'past']).optional() });
const rescheduleBody = z.object({
  scheduledAt: z.coerce.date().optional(),
  format: z.enum(['in_person', 'remote']).optional(),
});
const respondBody = z.object({ decision: z.enum(['accept', 'decline']) });

router.get('/', authGuard, validate({ query: listQuery }), sessionController.listMine);
router.get('/:id', authGuard, validate({ params: idParam }), sessionController.read);
router.patch('/:id', authGuard, validate({ params: idParam, body: rescheduleBody }), sessionController.reschedule);
router.delete('/:id', authGuard, validate({ params: idParam }), sessionController.cancel);
router.post('/:id/respond', authGuard, validate({ params: idParam, body: respondBody }), sessionController.respond);
router.post('/:id/confirm-complete', authGuard, validate({ params: idParam }), sessionController.confirmComplete);
router.post('/:id/no-show', authGuard, validate({ params: idParam }), sessionController.reportNoShow);
router.post('/:id/join', authGuard, validate({ params: idParam }), sessionController.join);

export default router;
