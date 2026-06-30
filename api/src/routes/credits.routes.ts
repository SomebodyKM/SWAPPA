import { Router } from 'express';
import { z } from 'zod';
import { creditController } from '../controllers/credit.controller';
import { authGuard } from '../middleware/auth.middleware';
import { validate } from '../middleware/validate.middleware';

const router = Router();

const listQuery = z.object({
  cursor: z.string().length(24).optional(),
  limit: z.coerce.number().int().positive().max(100).optional(),
});

router.get('/', authGuard, creditController.balance);
router.get('/transactions', authGuard, validate({ query: listQuery }), creditController.transactions);
router.get('/packs', authGuard, creditController.packs);

export default router;
