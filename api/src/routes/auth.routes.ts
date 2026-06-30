import { Router } from 'express';
import { z } from 'zod';
import { authController } from '../controllers/auth.controller';
import { validate } from '../middleware/validate.middleware';
import { authLimiter } from '../middleware/rateLimit.middleware';

const router = Router();

const registerBody = z.object({
  email: z.email(),
  phone: z.string().min(5).max(20).optional(),
  password: z.string().min(8).max(128),
  displayName: z.string().min(1).max(80),
  deviceFingerprint: z.string().max(200).optional(),
});

const verifyBody = z.object({
  email: z.email(),
  code: z.string().min(4).max(10),
});

const resendBody = z.object({ email: z.email() });

const loginBody = z.object({
  emailOrPhone: z.string().min(3),
  password: z.string().min(1),
});

const refreshBody = z.object({ refreshToken: z.string().min(10) });

router.post('/register', authLimiter, validate({ body: registerBody }), authController.register);
router.post('/verify-email', authLimiter, validate({ body: verifyBody }), authController.verifyEmail);
router.post('/resend-code', authLimiter, validate({ body: resendBody }), authController.resendCode);
router.post('/login', authLimiter, validate({ body: loginBody }), authController.login);
router.post('/refresh', validate({ body: refreshBody }), authController.refresh);
router.post('/logout', authController.logout);

export default router;
