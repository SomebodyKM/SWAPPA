import { Router } from 'express';
import { z } from 'zod';
import { bugReportController } from '../controllers/bugReport.controller';
import { authGuard } from '../middleware/auth.middleware';
import { validate } from '../middleware/validate.middleware';

const router = Router();

const submitBody = z.object({ description: z.string().min(1).max(2000) });

router.get('/mine', authGuard, bugReportController.listMine);
router.post('/', authGuard, validate({ body: submitBody }), bugReportController.submit);

export default router;
