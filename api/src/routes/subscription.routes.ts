import { Router } from 'express';
import { subscriptionController } from '../controllers/subscription.controller';
import { authGuard } from '../middleware/auth.middleware';

const router = Router();

router.get('/', authGuard, subscriptionController.get);
router.get('/offerings', authGuard, subscriptionController.offerings);

export default router;
