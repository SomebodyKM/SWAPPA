import { Router } from 'express';
import { z } from 'zod';
import { messagingController } from '../controllers/messaging.controller';
import { authGuard } from '../middleware/auth.middleware';
import { validate } from '../middleware/validate.middleware';

const router = Router();

const idParam = z.object({ id: z.string().length(24) });
const editBody = z.object({ body: z.string().min(1).max(4000) });

router.get('/:id', authGuard, validate({ params: idParam }), messagingController.getMessage);
router.patch('/:id', authGuard, validate({ params: idParam, body: editBody }), messagingController.editMessage);
router.delete('/:id', authGuard, validate({ params: idParam }), messagingController.deleteMessage);

export default router;
