import { RequestHandler } from 'express';
import { authService } from '../services/auth.service';

export const authController: Record<string, RequestHandler> = {
  // Creates an unverified account and emails a verification code. No tokens yet.
  register: async (req, res) => {
    const { userId, email } = await authService.register(req.body);
    res.status(201).json({
      userId,
      email,
      verificationRequired: true,
      message: 'Account created. Check your email for a verification code.',
    });
  },

  // Confirms the email code and returns auth tokens.
  verifyEmail: async (req, res) => {
    const { email, code } = req.body;
    const result = await authService.verifyEmail(email, code);
    res.json({
      user: result.user.toJSON(),
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    });
  },

  resendCode: async (req, res) => {
    await authService.resendEmailCode(req.body.email);
    res.json({ message: 'Verification code sent.' });
  },

  login: async (req, res) => {
    const { emailOrPhone, password } = req.body;
    const result = await authService.login(emailOrPhone, password);
    res.json({
      user: result.user.toJSON(),
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    });
  },

  refresh: async (req, res) => {
    const tokens = await authService.refresh(req.body.refreshToken);
    res.json(tokens);
  },

  // Stateless JWT: logout is a client-side token discard.
  logout: async (_req, res) => {
    res.status(204).send();
  },
};
