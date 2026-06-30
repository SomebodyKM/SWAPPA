import bcrypt from 'bcrypt';
import { User, UserDoc } from '../models/user.model';
import { signAccessToken, signRefreshToken, verifyRefreshToken } from '../utils/jwt';
import { verificationService } from './verification.service';
import { creditService } from './credit.service';
import { Errors } from '../utils/errors';

const SALT_ROUNDS = 12;

export interface RegisterInput {
  email: string;
  phone?: string;
  password: string;
  displayName: string;
  deviceFingerprint?: string;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

function issueTokens(user: UserDoc): AuthTokens {
  const payload = { sub: String(user._id), role: user.role };
  return { accessToken: signAccessToken(payload), refreshToken: signRefreshToken(payload) };
}

export const authService = {
  /**
   * Create an UNVERIFIED account and send an email verification code.
   * No tokens are issued until the email is verified (v1 verifies email only;
   * phone verification is a future update).
   */
  async register(input: RegisterInput): Promise<{ userId: string; email: string }> {
    const passwordHash = await bcrypt.hash(input.password, SALT_ROUNDS);
    let user: UserDoc;
    try {
      user = await User.create({
        email: input.email,
        phone: input.phone,
        passwordHash,
        displayName: input.displayName,
        deviceFingerprints: input.deviceFingerprint ? [input.deviceFingerprint] : [],
      });
    } catch (err) {
      if ((err as { code?: number }).code === 11000) {
        throw Errors.conflict('An account with that email or phone already exists', 'ACCOUNT_EXISTS');
      }
      throw err;
    }

    await verificationService.sendEmailCode(user);
    return { userId: String(user._id), email: user.email! };
  },

  /** Confirm the emailed code; on success the account is verified and tokens are issued. */
  async verifyEmail(email: string, code: string): Promise<{ user: UserDoc } & AuthTokens> {
    const user = await verificationService.verifyEmail(email, code);
    // One-time welcome credit grant now that the account is active (FR-019).
    await creditService.applyWelcomeGrant(user, user.deviceFingerprints[0]);
    return { user, ...issueTokens(user) };
  },

  /** Resend the email verification code (cooldown enforced in verification.service). */
  async resendEmailCode(email: string): Promise<void> {
    const user = await User.findOne({ email: email.toLowerCase() });
    if (!user) throw Errors.notFound('Account not found');
    if (user.emailVerified) throw Errors.badRequest('Email already verified');
    await verificationService.sendEmailCode(user);
  },

  async login(emailOrPhone: string, password: string): Promise<{ user: UserDoc } & AuthTokens> {
    const query = emailOrPhone.includes('@')
      ? { email: emailOrPhone.toLowerCase() }
      : { phone: emailOrPhone };
    const user = await User.findOne(query).select('+passwordHash');
    if (!user) throw Errors.unauthorized('Invalid credentials');
    if (user.status !== 'active') {
      throw Errors.forbidden('Account is not active', 'ACCOUNT_INACTIVE', { status: user.status });
    }
    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) throw Errors.unauthorized('Invalid credentials');
    if (!user.emailVerified) {
      throw Errors.forbidden('Email not verified', 'EMAIL_NOT_VERIFIED', { email: user.email });
    }
    return { user, ...issueTokens(user) };
  },

  async refresh(refreshToken: string): Promise<AuthTokens> {
    let payload;
    try {
      payload = verifyRefreshToken(refreshToken);
    } catch {
      throw Errors.unauthorized('Invalid or expired refresh token');
    }
    const user = await User.findById(payload.sub);
    if (!user || user.status !== 'active') throw Errors.unauthorized('Account not available');
    return issueTokens(user);
  },
};
