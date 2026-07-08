import { Router } from 'express';
import { z } from 'zod';
import { messagingController } from '../controllers/messaging.controller';
import { authGuard } from '../middleware/auth.middleware';
import { validate } from '../middleware/validate.middleware';

const router = Router();

const idParam = z.object({ id: z.string().length(24) });
const listMsgQuery = z.object({
  cursor: z.string().length(24).optional(),
  limit: z.coerce.number().int().positive().max(100).optional(),
});
const sendBody = z.object({
  type: z.enum(['text', 'image', 'audio', 'video']).optional(),
  body: z.string().max(4000).optional(),
  mediaUrl: z.string().url().optional(),
});
const createBody = z.object({ targetUserId: z.string().length(24) });

router.get('/', authGuard, messagingController.listConversations);
router.post('/', authGuard, validate({ body: createBody }), messagingController.createConversation);
router.get('/:id', authGuard, validate({ params: idParam }), messagingController.getConversation);
router.get(
  '/:id/messages',
  authGuard,
  validate({ params: idParam, query: listMsgQuery }),
  messagingController.listMessages,
);
router.post(
  '/:id/messages',
  authGuard,
  validate({ params: idParam, body: sendBody }),
  messagingController.sendMessage,
);

export default router;
