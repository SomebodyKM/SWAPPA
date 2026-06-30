import { Router } from 'express';
import { z } from 'zod';
import { notificationController } from '../controllers/notification.controller';
import { authGuard } from '../middleware/auth.middleware';
import { validate } from '../middleware/validate.middleware';

const router = Router();

const idParam = z.object({ id: z.string().length(24) });
const listQuery = z.object({
  cursor: z.string().length(24).optional(),
  limit: z.coerce.number().int().positive().max(100).optional(),
});

router.get('/', authGuard, validate({ query: listQuery }), notificationController.list);
router.post('/read-all', authGuard, notificationController.markAllRead);
router.patch('/:id', authGuard, validate({ params: idParam }), notificationController.markRead);
router.delete('/:id', authGuard, validate({ params: idParam }), notificationController.remove);

export default router;
