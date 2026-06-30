import { Router } from 'express';
import { z } from 'zod';
import { safetyController } from '../controllers/safety.controller';
import { authGuard } from '../middleware/auth.middleware';
import { validate } from '../middleware/validate.middleware';

const router = Router();

const reportBody = z.object({
  targetUserId: z.string().length(24),
  reason: z.string().min(1).max(1000),
});
const blockBody = z.object({ targetUserId: z.string().length(24) });
const targetParam = z.object({ targetUserId: z.string().length(24) });

router.get('/blocks', authGuard, safetyController.listBlocks);
router.post('/reports', authGuard, validate({ body: reportBody }), safetyController.report);
router.post('/blocks', authGuard, validate({ body: blockBody }), safetyController.block);
router.delete('/blocks/:targetUserId', authGuard, validate({ params: targetParam }), safetyController.unblock);

export default router;
