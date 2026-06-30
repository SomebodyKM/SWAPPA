import { User, UserDoc } from '../models/user.model';
import { CreditTransaction, CreditTxType, CreditTxAction } from '../models/creditTransaction.model';
import { CREDITS } from '../config/limits';
import { notificationService } from './notification.service';
import { Errors } from '../utils/errors';

interface LedgerEntry {
  user: string;
  type: CreditTxType;
  action?: CreditTxAction;
  basicDelta: number;
  boostDelta: number;
  basicAfter: number;
  boostAfter: number;
  refId: string;
  note?: string;
}

/** Append-only ledger write; idempotent on (refId, type). Returns false if already applied. */
async function writeLedger(entry: LedgerEntry): Promise<boolean> {
  try {
    await CreditTransaction.create({ ...entry, action: entry.action ?? null });
    return true;
  } catch (err) {
    if ((err as { code?: number }).code === 11000) return false; // duplicate → already applied
    throw err;
  }
}

function cycleKey(at: Date): number {
  return Math.floor(at.getTime() / CREDITS.refillCycleMs);
}

export const creditService = {
  /** Lazily refill Basic credits to cap on a cycle boundary (set, not add; no rollover). */
  async refillIfDue(user: UserDoc): Promise<boolean> {
    const now = new Date();
    const due = now.getTime() - user.credits.basic.lastRefillAt.getTime() >= CREDITS.refillCycleMs;
    if (!due) return false;

    user.credits.basic.balance = user.credits.basic.cap;
    user.credits.basic.lastRefillAt = now;
    await user.save();
    await writeLedger({
      user: String(user._id),
      type: 'refill',
      basicDelta: 0,
      boostDelta: 0,
      basicAfter: user.credits.basic.balance,
      boostAfter: user.credits.boost.balance,
      refId: `refill:${String(user._id)}:${cycleKey(now)}`,
      note: 'Cycle refill (set to cap)',
    });
    return true;
  },

  async getBalance(userId: string) {
    const user = await User.findById(userId);
    if (!user) throw Errors.notFound('User not found');
    await this.refillIfDue(user);
    return {
      basic: {
        balance: user.credits.basic.balance,
        cap: user.credits.basic.cap,
        nextRefillAt: new Date(user.credits.basic.lastRefillAt.getTime() + CREDITS.refillCycleMs),
      },
      boost: { balance: user.credits.boost.balance },
    };
  },

  /** One-time welcome grant of Basic credits, enforced per account and per device (FR-019). */
  async applyWelcomeGrant(user: UserDoc, deviceFingerprint?: string): Promise<void> {
    if (user.welcomeGrantApplied) return;
    if (deviceFingerprint) {
      const farmed = await User.exists({
        welcomeGrantApplied: true,
        deviceFingerprints: deviceFingerprint,
      });
      if (farmed) {
        user.welcomeGrantApplied = true; // mark to avoid re-checking; no credits granted
        await user.save();
        return;
      }
    }
    user.credits.basic.balance += CREDITS.welcomeGrant;
    user.welcomeGrantApplied = true;
    await user.save();
    await writeLedger({
      user: String(user._id),
      type: 'grant',
      basicDelta: CREDITS.welcomeGrant,
      boostDelta: 0,
      basicAfter: user.credits.basic.balance,
      boostAfter: user.credits.boost.balance,
      refId: `welcome:${String(user._id)}`,
      note: 'One-time welcome grant',
    });
  },

  /** Total available credits (Basic + Boost) after a lazy refill. */
  async availableCredits(userId: string): Promise<number> {
    const user = await User.findById(userId);
    if (!user) throw Errors.notFound('User not found');
    await this.refillIfDue(user);
    return user.credits.basic.balance + user.credits.boost.balance;
  },

  /**
   * Spend `cost` credits for an AI action — Basic first, then Boost (FR-015).
   * Throws 402 if insufficient. Writes a `spend` ledger row keyed by `refId`
   * (the AI request id) for idempotency. Caller must only invoke on success (FR-017).
   */
  async spend(
    userId: string,
    action: Exclude<CreditTxAction, null>,
    cost: number,
    refId: string,
  ): Promise<{ basicAfter: number; boostAfter: number; charged: number }> {
    const user = await User.findById(userId);
    if (!user) throw Errors.notFound('User not found');
    await this.refillIfDue(user);

    const total = user.credits.basic.balance + user.credits.boost.balance;
    if (total < cost) {
      throw Errors.paymentRequired('Insufficient credits', {
        required: cost,
        available: total,
        upgrade: 'Buy a Boost pack or upgrade to Premium',
      });
    }

    const basicDelta = -Math.min(cost, user.credits.basic.balance);
    const boostDelta = -(cost + basicDelta); // remainder from boost
    user.credits.basic.balance += basicDelta;
    user.credits.boost.balance += boostDelta;
    await user.save();

    await writeLedger({
      user: userId,
      type: 'spend',
      action,
      basicDelta,
      boostDelta,
      basicAfter: user.credits.basic.balance,
      boostAfter: user.credits.boost.balance,
      refId,
      note: `AI: ${action}`,
    });

    const remaining = user.credits.basic.balance + user.credits.boost.balance;
    if (remaining <= CREDITS.lowBalanceThreshold) {
      await notificationService.notify({
        userId,
        type: 'credits_low',
        title: 'Low on credits',
        body: 'Your credit balance is running low',
        data: { basic: user.credits.basic.balance, boost: user.credits.boost.balance },
      });
    }
    return {
      basicAfter: user.credits.basic.balance,
      boostAfter: user.credits.boost.balance,
      charged: cost,
    };
  },

  /** Credit Boost balance (used by the RevenueCat consumable webhook in US7). Idempotent on refId. */
  async grantBoost(userId: string, amount: number, refId: string): Promise<boolean> {
    const user = await User.findById(userId);
    if (!user) throw Errors.notFound('User not found');
    // Idempotency: if this purchase was already recorded, do nothing.
    const applied = await writeLedger({
      user: userId,
      type: 'purchase',
      basicDelta: 0,
      boostDelta: amount,
      basicAfter: user.credits.basic.balance,
      boostAfter: user.credits.boost.balance + amount,
      refId,
      note: 'Boost pack purchase',
    });
    if (!applied) return false;
    user.credits.boost.balance += amount;
    await user.save();
    return true;
  },

  async listTransactions(
    userId: string,
    opts: { cursor?: string; limit: number },
  ) {
    const filter: Record<string, unknown> = { user: userId };
    if (opts.cursor) filter._id = { $lt: opts.cursor };
    const docs = await CreditTransaction.find(filter)
      .sort({ _id: -1 })
      .limit(opts.limit + 1);
    const hasMore = docs.length > opts.limit;
    const items = hasMore ? docs.slice(0, opts.limit) : docs;
    return { items, nextCursor: hasMore ? String(items[items.length - 1]._id) : null };
  },
};
