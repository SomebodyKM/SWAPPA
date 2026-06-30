import { Router } from 'express';
import { z } from 'zod';
import { adminController } from '../controllers/admin.controller';
import { authGuard } from '../middleware/auth.middleware';
import { adminGuard } from '../middleware/admin.middleware';
import { validate } from '../middleware/validate.middleware';

const router = Router();

// All admin routes require an authenticated admin.
router.use(authGuard, adminGuard);

const idParam = z.object({ id: z.string().length(24) });
const skillBody = z.object({ name: z.string().min(1).max(80), category: z.string().min(1).max(60) });
const skillEditBody = z.object({
  name: z.string().min(1).max(80).optional(),
  category: z.string().min(1).max(60).optional(),
  aliases: z.array(z.string()).optional(),
  status: z.enum(['approved', 'pending']).optional(),
});
const reasonBody = z.object({ reason: z.string().min(1).max(1000) });
const roleBody = z.object({ role: z.enum(['user', 'admin']) });
const noteBody = z.object({ note: z.string().max(1000).optional() });

// Skills
router.get('/skills/pending', adminController.pendingSkills);
router.post('/skills', validate({ body: skillBody }), adminController.createSkill);
router.patch('/skills/:id', validate({ params: idParam, body: skillEditBody }), adminController.updateSkill);
router.delete('/skills/:id', validate({ params: idParam }), adminController.deleteSkill);

// Users
router.get('/users', adminController.listUsers);
router.post('/users/:id/ban', validate({ params: idParam, body: reasonBody }), adminController.banUser);
router.post('/users/:id/suspend', validate({ params: idParam, body: reasonBody }), adminController.suspendUser);
router.post('/users/:id/unban', validate({ params: idParam }), adminController.unbanUser);
router.patch('/users/:id/role', validate({ params: idParam, body: roleBody }), adminController.setRole);

// Reports
router.get('/reports', adminController.listReports);
router.post('/reports/:id/resolve', validate({ params: idParam, body: noteBody }), adminController.resolveReport);
router.post('/reports/:id/dismiss', validate({ params: idParam, body: noteBody }), adminController.dismissReport);

// Audit + metrics
router.get('/audit-log', adminController.auditLog);
router.get('/metrics', adminController.metrics);

export default router;
