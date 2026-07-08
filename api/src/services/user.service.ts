import bcrypt from 'bcrypt';
import { User, UserDoc } from '../models/user.model';
import { SkillTag } from '../models/skillTag.model';
import { Verification } from '../models/verification.model';
import { CreditTransaction } from '../models/creditTransaction.model';
import { AIRequest } from '../models/aiRequest.model';
import { Subscription } from '../models/subscription.model';
import { Notification } from '../models/notification.model';
import { Review } from '../models/review.model';
import { Report } from '../models/report.model';
import { Session } from '../models/session.model';
import { Swap } from '../models/swap.model';
import { Conversation } from '../models/conversation.model';
import { Message } from '../models/message.model';
import { Errors, AppError } from '../utils/errors';
import { assertStrongPassword } from '../utils/passwordStrength';
import { verificationService } from './verification.service';

const SALT_ROUNDS = 12;

export interface UpdateProfileInput {
  displayName?: string;
  bio?: string;
  photoUrl?: string;
  phone?: string;
  onboardingComplete?: boolean; // set once the post-signup profile+skills setup is done
}

export const userService = {
  async getById(id: string): Promise<UserDoc> {
    const user = await User.findById(id);
    if (!user) throw Errors.notFound('User not found');
    return user;
  },

  async updateProfile(userId: string, input: UpdateProfileInput): Promise<UserDoc> {
    const user = await User.findById(userId);
    if (!user) throw Errors.notFound('User not found');

    if (input.displayName !== undefined) user.displayName = input.displayName;
    if (input.bio !== undefined) user.bio = input.bio;
    if (input.photoUrl !== undefined) user.photoUrl = input.photoUrl;
    if (input.phone !== undefined) user.phone = input.phone;

    if (input.onboardingComplete !== undefined) {
      user.onboardingComplete = input.onboardingComplete;
    }

    await user.save();
    return user;
  },

  async addPushToken(userId: string, token: string): Promise<void> {
    await User.updateOne({ _id: userId }, { $addToSet: { pushTokens: token } });
  },

  /**
   * Changes the account email and immediately re-sends a verification code —
   * the new address is unverified until confirmed via `/auth/verify-email`,
   * mirroring the registration flow.
   */
  async changeEmail(userId: string, email: string): Promise<UserDoc> {
    const normalized = email.toLowerCase().trim();
    const user = await User.findById(userId);
    if (!user) throw Errors.notFound('User not found');
    if (user.email === normalized) {
      throw Errors.badRequest('That’s already your email', { field: 'email' });
    }
    const taken = await User.exists({ email: normalized, _id: { $ne: userId } });
    if (taken) throw Errors.badRequest('That email is already in use', { field: 'email' });

    user.email = normalized;
    user.emailVerified = false;
    await user.save();
    await verificationService.sendEmailCode(user);
    return user;
  },

  /** Verifies the current password before setting a new one (also zxcvbn-checked). */
  async changePassword(userId: string, currentPassword: string, newPassword: string): Promise<void> {
    const user = await User.findById(userId).select('+passwordHash');
    if (!user) throw Errors.notFound('User not found');

    const ok = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!ok) {
      throw new AppError(400, 'WRONG_PASSWORD', 'Current password is incorrect', {
        field: 'currentPassword',
      });
    }
    assertStrongPassword(newPassword, [user.email ?? '', user.displayName]);

    user.passwordHash = await bcrypt.hash(newPassword, SALT_ROUNDS);
    await user.save();
  },

  async deleteAccount(userId: string): Promise<void> {
    // Hard delete the user and everything keyed to them, so the email/phone is
    // freed and no orphaned data remains. (Retention/anonymization policy for
    // production is a follow-up — analysis U2.)
    const convs = await Conversation.find({ participants: userId }).select('_id');
    const convIds = convs.map((c) => c._id);

    await Promise.all([
      SkillTag.deleteMany({ user: userId }),
      Verification.deleteMany({ user: userId }),
      CreditTransaction.deleteMany({ user: userId }),
      AIRequest.deleteMany({ user: userId }),
      Subscription.deleteMany({ user: userId }),
      Notification.deleteMany({ user: userId }),
      Review.deleteMany({ $or: [{ reviewer: userId }, { reviewee: userId }] }),
      Report.deleteMany({ $or: [{ reporter: userId }, { target: userId }] }),
      Session.deleteMany({ $or: [{ teacher: userId }, { learner: userId }] }),
      Swap.deleteMany({ participants: userId }),
      Message.deleteMany({ conversation: { $in: convIds } }),
    ]);
    await Conversation.deleteMany({ participants: userId });
    await User.deleteOne({ _id: userId });
  },
};
