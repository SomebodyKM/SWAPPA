import { Router } from 'express';
import authRoutes from './auth.routes';
import usersRoutes from './users.routes';
import skillsRoutes from './skills.routes';
import matchesRoutes from './matches.routes';
import mediaRoutes from './media.routes';
import conversationsRoutes from './conversations.routes';
import messagesRoutes from './messages.routes';
import swapsRoutes from './swaps.routes';
import sessionsRoutes from './sessions.routes';
import reviewsRoutes from './reviews.routes';
import creditsRoutes from './credits.routes';
import aiRoutes from './ai.routes';
import subscriptionRoutes from './subscription.routes';
import safetyRoutes from './safety.routes';
import bugReportsRoutes from './bugReports.routes';
import adminRoutes from './admin.routes';
import notificationsRoutes from './notifications.routes';
import webhookRoutes from './webhook.routes';

const router = Router();

router.get('/health', (_req, res) => res.json({ status: 'ok', ts: Date.now() }));

router.use('/auth', authRoutes);
router.use('/users', usersRoutes);
router.use('/skills', skillsRoutes);
router.use('/matches', matchesRoutes);
router.use('/media', mediaRoutes);
router.use('/conversations', conversationsRoutes);
router.use('/messages', messagesRoutes);
router.use('/swaps', swapsRoutes);
router.use('/sessions', sessionsRoutes);
router.use('/reviews', reviewsRoutes);
router.use('/credits', creditsRoutes);
router.use('/ai', aiRoutes);
router.use('/subscription', subscriptionRoutes);
router.use('/safety', safetyRoutes);
router.use('/bug-reports', bugReportsRoutes);
router.use('/admin', adminRoutes);
router.use('/notifications', notificationsRoutes);
router.use('/webhooks', webhookRoutes);

export default router;
