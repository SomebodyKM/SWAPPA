import { Types } from 'mongoose';
import { User, UserDoc } from '../models/user.model';
import { Subscription, SubscriptionDoc } from '../models/subscription.model';
import { creditService } from './credit.service';
import { notificationService } from './notification.service';
import { BOOST_PACKS, TIER_LIMITS } from '../config/limits';
import { logger } from '../utils/logger';

/** Minimal shape of a RevenueCat webhook event (fields we use). */
export interface RevenueCatEvent {
  type: string;
  id?: string;
  app_user_id: string;
  product_id?: string;
  transaction_id?: string;
  entitlement_ids?: string[];
  expiration_at_ms?: number;
}

const PREMIUM_ACTIVATING = ['INITIAL_PURCHASE', 'RENEWAL', 'UNCANCELLATION', 'PRODUCT_CHANGE'];

async function findUser(appUserId: string): Promise<UserDoc | null> {
  if (!Types.ObjectId.isValid(appUserId)) return null;
  return User.findById(appUserId);
}

async function getSubscription(userId: Types.ObjectId) {
  let sub = await Subscription.findOne({ user: userId });
  if (!sub) sub = await Subscription.create({ user: userId, tier: 'free', status: 'expired' });
  return sub;
}

export const subscriptionService = {
  async getForUser(userId: string) {
    const sub = await getSubscription(new Types.ObjectId(userId));
    return {
      tier: sub.tier,
      status: sub.status,
      currentPeriodEnd: sub.currentPeriodEnd,
      premiumBenefits: {
        matchResults: TIER_LIMITS.premium.matchResults,
        mapRadiusMeters: TIER_LIMITS.premium.mapRadiusMeters,
        activeSwaps: TIER_LIMITS.premium.activeSwaps,
        skillTags: TIER_LIMITS.premium.skillTags,
        multimediaMessaging: TIER_LIMITS.premium.multimediaMessaging,
        basicCreditCap: TIER_LIMITS.premium.basicCreditCap,
      },
    };
  },

  /** Process a RevenueCat webhook event — source of truth for credits & tier. */
  async handleEvent(event: RevenueCatEvent): Promise<void> {
    const user = await findUser(event.app_user_id);
    if (!user) {
      logger.warn(`[revenuecat] unknown app_user_id ${event.app_user_id}; ignoring ${event.type}`);
      return;
    }

    // Consumable (Boost pack) — RevenueCat does not grant these; we do.
    if (event.type === 'NON_RENEWING_PURCHASE') {
      const packSize = event.product_id ? BOOST_PACKS[event.product_id] : undefined;
      if (!packSize) return logger.warn(`[revenuecat] unknown Boost product ${event.product_id}`);
      const refId = event.transaction_id ?? event.id ?? `${event.app_user_id}:${Date.now()}`;
      const applied = await creditService.grantBoost(String(user._id), packSize, refId);
      if (applied) {
        const balance = await creditService.getBalance(String(user._id));
        await notificationService.notify({
          userId: String(user._id),
          type: 'credits_topped_up',
          title: 'Boost credits added',
          body: `${packSize} Boost credits added to your account`,
          data: { boostDelta: packSize, balanceAfter: balance.boost.balance },
        });
      }
      return;
    }

    // Subscription lifecycle
    const sub = await getSubscription(user._id);
    if (event.id && sub.lastEventId === event.id) return; // idempotent on event id

    if (PREMIUM_ACTIVATING.includes(event.type)) {
      await this.activatePremium(user, sub, event);
    } else if (event.type === 'CANCELLATION') {
      sub.status = 'cancelled'; // keep Premium until currentPeriodEnd
      sub.lastEventId = event.id ?? sub.lastEventId;
      await sub.save();
    } else if (event.type === 'EXPIRATION') {
      await this.revertToFree(user, sub, event);
    } else if (event.type === 'BILLING_ISSUE') {
      sub.status = 'grace';
      sub.lastEventId = event.id ?? sub.lastEventId;
      await sub.save();
    } else {
      logger.debug(`[revenuecat] unhandled event type ${event.type}`);
    }
  },

  async activatePremium(user: UserDoc, sub: SubscriptionDoc, event: RevenueCatEvent): Promise<void> {
    sub.tier = 'premium';
    sub.status = 'active';
    sub.productId = event.product_id ?? sub.productId;
    sub.entitlement = event.entitlement_ids?.[0] ?? 'premium';
    sub.currentPeriodEnd = event.expiration_at_ms ? new Date(event.expiration_at_ms) : null;
    sub.lastEventId = event.id ?? sub.lastEventId;
    await sub.save();

    // Apply immediately: tier + larger Basic cap (refill still only on cycle boundary — FR-030/FR-032).
    user.tier = 'premium';
    user.credits.basic.cap = TIER_LIMITS.premium.basicCreditCap;
    await user.save();

    await notificationService.notify({
      userId: String(user._id),
      type: 'subscription_changed',
      title: 'Premium active',
      body: 'Your Premium benefits are now active',
      data: { tier: 'premium', status: 'active' },
    });
  },

  async revertToFree(user: UserDoc, sub: SubscriptionDoc, event: RevenueCatEvent): Promise<void> {
    sub.tier = 'free';
    sub.status = 'expired';
    sub.lastEventId = event.id ?? sub.lastEventId;
    await sub.save();

    // Revert tier + cap; PRESERVE all other data (FR-021/FR-032). Balance settles to
    // the new cap on the next refill (no immediate clamp).
    user.tier = 'free';
    user.credits.basic.cap = TIER_LIMITS.free.basicCreditCap;
    await user.save();

    await notificationService.notify({
      userId: String(user._id),
      type: 'subscription_changed',
      title: 'Premium ended',
      body: 'Your Premium has lapsed — you are back on the free plan',
      data: { tier: 'free', status: 'expired' },
    });
  },
};
