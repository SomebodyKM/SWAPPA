import { Router } from 'express';
import { z } from 'zod';
import { mediaController } from '../controllers/media.controller';
import { authGuard } from '../middleware/auth.middleware';
import { validate } from '../middleware/validate.middleware';

const router = Router();

const signBody = z.object({ purpose: z.enum(['avatar', 'message']) });

router.post('/sign', authGuard, validate({ body: signBody }), mediaController.sign);

export default router;
