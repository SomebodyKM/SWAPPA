import { Router } from 'express';
import { z } from 'zod';
import { userController } from '../controllers/user.controller';
import { skillController } from '../controllers/skill.controller';
import { reviewController } from '../controllers/review.controller';
import { authGuard } from '../middleware/auth.middleware';
import { validate } from '../middleware/validate.middleware';

const router = Router();

const idParam = z.object({ id: z.string().length(24) });

const updateBody = z.object({
  displayName: z.string().min(1).max(80).optional(),
  bio: z.string().max(500).optional(),
  photoUrl: z.string().url().optional(),
  location: z.object({ lng: z.number(), lat: z.number() }).optional(),
  locationPrecision: z.enum(['approximate', 'precise']).optional(),
  consent: z.boolean().optional(),
});

const pushTokenBody = z.object({ token: z.string().min(10) });

const addTagBody = z.object({
  skillId: z.string().length(24),
  kind: z.enum(['offer', 'want']),
  proficiency: z.enum(['beginner', 'intermediate', 'advanced', 'expert']).optional(),
});
const updateTagBody = z.object({
  proficiency: z.enum(['beginner', 'intermediate', 'advanced', 'expert']),
});
const tagIdParam = z.object({ tagId: z.string().length(24) });

// Profile
router.get('/me', authGuard, userController.me);
router.patch('/me', authGuard, validate({ body: updateBody }), userController.updateMe);
router.post('/me/push-tokens', authGuard, validate({ body: pushTokenBody }), userController.addPushToken);
router.delete('/me', authGuard, userController.deleteMe);

// My skill tags (BREAD)
router.get('/me/tags', authGuard, skillController.listMyTags);
router.post('/me/tags', authGuard, validate({ body: addTagBody }), skillController.addTag);
router.patch('/me/tags/:tagId', authGuard, validate({ params: tagIdParam, body: updateTagBody }), skillController.updateTag);
router.delete('/me/tags/:tagId', authGuard, validate({ params: tagIdParam }), skillController.removeTag);

// Public profile + a user's public tags + reviews
router.get('/:id', authGuard, validate({ params: idParam }), userController.getById);
router.get('/:id/tags', authGuard, validate({ params: idParam }), skillController.listUserTags);
router.get('/:id/reviews', authGuard, validate({ params: idParam }), reviewController.listForUser);

export default router;
