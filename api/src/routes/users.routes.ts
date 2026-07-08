import { Router } from 'express';
import { z } from 'zod';
import { userController } from '../controllers/user.controller';
import { skillController } from '../controllers/skill.controller';
import { reviewController } from '../controllers/review.controller';
import { authGuard } from '../middleware/auth.middleware';
import { validate } from '../middleware/validate.middleware';
import { locationUpdateLimiter } from '../middleware/locationRateLimit.middleware';

const router = Router();

const idParam = z.object({ id: z.string().length(24) });

const updateBody = z.object({
  displayName: z.string().min(1).max(80).optional(),
  bio: z.string().max(500).optional(),
  photoUrl: z.string().url().optional(),
  phone: z.string().min(5, { message: 'Enter a valid phone number' }).max(20).optional(),
  onboardingComplete: z.boolean().optional(),
});

const locationSuggestQuery = z.object({ query: z.string().min(1).max(200) });
const locationUpdateBody = z.union([
  z.object({ placeId: z.string().min(1) }),
  z.object({
    lat: z.number().min(-90).max(90),
    lng: z.number().min(-180).max(180),
    source: z.literal('device'),
  }),
]);

const emailBody = z.object({ email: z.email({ message: 'Enter a valid email address' }) });
const passwordChangeBody = z.object({
  currentPassword: z.string().min(1, { message: 'Enter your current password' }),
  newPassword: z.string().min(8, { message: 'Password must be at least 8 characters' }).max(128),
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
router.patch('/me/email', authGuard, validate({ body: emailBody }), userController.changeEmail);
router.patch('/me/password', authGuard, validate({ body: passwordChangeBody }), userController.changePassword);
router.post('/me/push-tokens', authGuard, validate({ body: pushTokenBody }), userController.addPushToken);
router.delete('/me', authGuard, userController.deleteMe);

// Location (manual place search + coarse auto-locate — always server-rounded)
router.get(
  '/me/location/suggest',
  authGuard,
  validate({ query: locationSuggestQuery }),
  userController.suggestLocation,
);
router.patch(
  '/me/location',
  authGuard,
  locationUpdateLimiter,
  validate({ body: locationUpdateBody }),
  userController.updateLocation,
);
router.delete('/me/location', authGuard, userController.clearLocation);

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
