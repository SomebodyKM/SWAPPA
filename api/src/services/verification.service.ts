import crypto from 'crypto';
import bcrypt from 'bcrypt';
import { Verification } from '../models/verification.model';
import { User, UserDoc } from '../models/user.model';
import { mailer } from './notifiers/mailer';
import { OTP } from '../config/limits';
import { Errors } from '../utils/errors';

function generateCode(length: number): string {
  // numeric OTP, zero-padded
  const max = 10 ** length;
  return crypto.randomInt(0, max).toString().padStart(length, '0');
}

export const verificationService = {
  /**
   * Create (or refresh) an email verification challenge and send the code.
   * Enforces a resend cooldown. v1 supports the 'email' channel only.
   */
  async sendEmailCode(user: UserDoc): Promise<void> {
    if (!user.email) throw Errors.badRequest('No email on file to verify');

    const existing = await Verification.findOne({ user: user._id, channel: 'email' });
    if (existing && Date.now() - existing.lastSentAt.getTime() < OTP.resendCooldownMs) {
      throw Errors.badRequest('Please wait before requesting another code', {
        retryAfterMs: OTP.resendCooldownMs - (Date.now() - existing.lastSentAt.getTime()),
      });
    }

    const code = generateCode(OTP.length);
    const codeHash = await bcrypt.hash(code, 10);
    const expiresAt = new Date(Date.now() + OTP.ttlMs);

    await Verification.findOneAndUpdate(
      { user: user._id, channel: 'email' },
      {
        user: user._id,
        channel: 'email',
        target: user.email,
        codeHash,
        expiresAt,
        attempts: 0,
        lastSentAt: new Date(),
        consumedAt: null,
      },
      { upsert: true, new: true },
    );

    await mailer.send({
      to: user.email,
      subject: 'Your SWAPPA verification code',
      text: `Your SWAPPA verification code is ${code}. It expires in ${Math.round(
        OTP.ttlMs / 60000,
      )} minutes.`,
    });
  },

  /** Verify an emailed code; marks the user email-verified on success. */
  async verifyEmail(email: string, code: string): Promise<UserDoc> {
    const user = await User.findOne({ email: email.toLowerCase() });
    if (!user) throw Errors.notFound('Account not found');
    if (user.emailVerified) return user;

    const challenge = await Verification.findOne({ user: user._id, channel: 'email' });
    if (!challenge || challenge.consumedAt) throw Errors.badRequest('No active verification code');
    if (challenge.expiresAt.getTime() < Date.now()) {
      throw Errors.badRequest('Verification code expired; request a new one');
    }
    if (challenge.attempts >= OTP.maxAttempts) {
      throw Errors.badRequest('Too many attempts; request a new code');
    }

    const ok = await bcrypt.compare(code, challenge.codeHash);
    if (!ok) {
      challenge.attempts += 1;
      await challenge.save();
      throw Errors.badRequest('Incorrect code');
    }

    challenge.consumedAt = new Date();
    await challenge.save();

    user.emailVerified = true;
    user.verifiedAt = new Date();
    await user.save();
    return user;
  },
};
