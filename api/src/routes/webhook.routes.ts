import { Router } from 'express';
import { subscriptionController } from '../controllers/subscription.controller';
import { webhookAuth } from '../middleware/webhookAuth.middleware';

const router = Router();

// RevenueCat server-to-server webhook (no JWT; shared-secret auth).
router.post('/revenuecat', webhookAuth, subscriptionController.webhook);

export default router;
