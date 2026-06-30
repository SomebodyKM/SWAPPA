import { Types } from 'mongoose';
import { Swap, SwapDoc, SwapStatus, ACTIVE_SWAP_STATUSES } from '../models/swap.model';
import { User } from '../models/user.model';
import { Skill } from '../models/skill.model';
import { tierLimits, ANTI_SPAM } from '../config/limits';
import { messagingService } from './messaging.service';
import { notificationService } from './notification.service';
import { Errors } from '../utils/errors';

async function assertParticipant(swapId: string, userId: string): Promise<SwapDoc> {
  const swap = await Swap.findById(swapId);
  if (!swap) throw Errors.notFound('Swap not found');
  if (!swap.participants.some((p) => String(p) === userId)) {
    throw Errors.forbidden('Not a participant of this swap');
  }
  return swap;
}

export const swapService = {
  async countActiveSwaps(userId: string, excludeSwapId?: string): Promise<number> {
    const filter: Record<string, unknown> = {
      participants: new Types.ObjectId(userId),
      status: { $in: ACTIVE_SWAP_STATUSES },
    };
    if (excludeSwapId) filter._id = { $ne: new Types.ObjectId(excludeSwapId) };
    return Swap.countDocuments(filter);
  },

  async assertUnderActiveLimit(userId: string, excludeSwapId?: string): Promise<void> {
    const user = await User.findById(userId).select('tier');
    if (!user) throw Errors.notFound('User not found');
    const cap = tierLimits(user.tier).activeSwaps;
    const count = await this.countActiveSwaps(userId, excludeSwapId);
    if (count >= cap) {
      throw Errors.limitReached('Active swap limit reached', {
        limit: cap,
        tier: user.tier,
        premiumUnlocksMore: user.tier === 'free',
      });
    }
  },

  async createSwap(
    initiatorId: string,
    input: { partnerId: string; offeredSkillId: string; requestedSkillId: string },
  ): Promise<SwapDoc> {
    if (input.partnerId === initiatorId) throw Errors.badRequest('Cannot swap with yourself');

    const partner = await User.findById(input.partnerId).select('status');
    if (!partner || partner.status !== 'active') throw Errors.notFound('Partner not available');

    const [offered, requested] = await Promise.all([
      Skill.findById(input.offeredSkillId),
      Skill.findById(input.requestedSkillId),
    ]);
    if (!offered || !requested) throw Errors.badRequest('Invalid skill reference');

    await this.assertUnderActiveLimit(initiatorId);

    const conversation = await messagingService.getOrCreateConversation(initiatorId, input.partnerId);

    const swap = await Swap.create({
      participants: [new Types.ObjectId(initiatorId), new Types.ObjectId(input.partnerId)],
      initiator: initiatorId,
      partner: input.partnerId,
      offeredSkill: input.offeredSkillId,
      requestedSkill: input.requestedSkillId,
      status: 'requested',
      conversation: conversation._id,
    });

    await notificationService.notify({
      userId: input.partnerId,
      type: 'swap_requested',
      title: 'New swap request',
      body: 'Someone wants to swap skills with you',
      data: { swapId: String(swap._id), fromUserId: initiatorId },
    });
    return swap;
  },

  async acceptSwap(swapId: string, userId: string): Promise<SwapDoc> {
    const swap = await assertParticipant(swapId, userId);
    if (String(swap.partner) !== userId) throw Errors.forbidden('Only the invited partner can accept');
    if (swap.status !== 'requested') throw Errors.conflict('Swap is not pending acceptance');

    await this.assertUnderActiveLimit(userId, swapId);

    swap.status = 'active';
    await swap.save();
    await notificationService.notify({
      userId: String(swap.initiator),
      type: 'swap_status_changed',
      title: 'Swap accepted',
      body: 'Your swap request was accepted',
      data: { swapId: String(swap._id), status: 'active' },
    });
    return swap;
  },

  async cancelSwap(swapId: string, userId: string): Promise<SwapDoc> {
    const swap = await assertParticipant(swapId, userId);
    if (!['requested', 'active'].includes(swap.status)) {
      throw Errors.conflict('Swap cannot be cancelled in its current state');
    }
    swap.status = 'cancelled';
    await swap.save();
    const otherId = swap.participants.map(String).find((id) => id !== userId)!;
    await notificationService.notify({
      userId: otherId,
      type: 'swap_status_changed',
      title: 'Swap cancelled',
      body: 'A swap was cancelled',
      data: { swapId: String(swap._id), status: 'cancelled' },
    });
    return swap;
  },

  async editSwap(
    swapId: string,
    userId: string,
    input: { offeredSkillId?: string; requestedSkillId?: string },
  ): Promise<SwapDoc> {
    const swap = await assertParticipant(swapId, userId);
    if (String(swap.initiator) !== userId) throw Errors.forbidden('Only the initiator can edit terms');
    if (swap.status !== 'requested') throw Errors.conflict('Only pending swaps can be edited');
    if (input.offeredSkillId) swap.offeredSkill = new Types.ObjectId(input.offeredSkillId);
    if (input.requestedSkillId) swap.requestedSkill = new Types.ObjectId(input.requestedSkillId);
    await swap.save();
    return swap;
  },

  async withdrawSwap(swapId: string, userId: string): Promise<void> {
    const swap = await assertParticipant(swapId, userId);
    if (String(swap.initiator) !== userId) throw Errors.forbidden('Only the initiator can withdraw');
    if (swap.status !== 'requested') throw Errors.conflict('Only pending swaps can be withdrawn');
    await Swap.deleteOne({ _id: swapId });
  },

  async listSwaps(userId: string, status?: SwapStatus): Promise<SwapDoc[]> {
    const filter: Record<string, unknown> = { participants: userId };
    if (status) filter.status = status;
    return Swap.find(filter)
      .sort({ updatedAt: -1 })
      .populate('offeredSkill requestedSkill', 'name category')
      .populate('participants', 'displayName photoUrl');
  },

  async getSwap(swapId: string, userId: string): Promise<SwapDoc> {
    const swap = await assertParticipant(swapId, userId);
    await swap.populate('offeredSkill requestedSkill', 'name category');
    await swap.populate('participants', 'displayName photoUrl ratingAvg');
    return swap;
  },

  /** Mark a swap completed (called when both parties confirm a session). Releases the slot. */
  async markCompleted(swapId: string): Promise<SwapDoc> {
    const swap = await Swap.findById(swapId);
    if (!swap) throw Errors.notFound('Swap not found');
    if (swap.status === 'completed') return swap;
    if (swap.status !== 'active') throw Errors.conflict('Only active swaps can be completed');
    swap.status = 'completed';
    await swap.save();
    return swap;
  },

  /**
   * Record that a no-show occurred for the swap and start the abandon grace window
   * (anti-spam: a swap may only be abandoned after this window elapses — FR-038).
   */
  async recordNoShow(swapId: string): Promise<void> {
    const swap = await Swap.findById(swapId);
    if (!swap) return;
    const now = new Date();
    swap.noShowReportedAt = now;
    swap.abandonAllowedAt = new Date(now.getTime() + ANTI_SPAM.noShowAbandonWindowHours * 3600_000);
    await swap.save();
  },

  /** Abandon a swap — allowed only after the no-show grace window (FR-038). Releases the slot. */
  async abandonSwap(swapId: string, userId: string): Promise<SwapDoc> {
    const swap = await assertParticipant(swapId, userId);
    if (swap.status !== 'active') throw Errors.conflict('Only active swaps can be abandoned');
    if (!swap.abandonAllowedAt || swap.abandonAllowedAt.getTime() > Date.now()) {
      throw Errors.forbidden(
        'A swap can only be abandoned after the no-show grace window',
        'ABANDON_NOT_YET_ALLOWED',
        { allowedAt: swap.abandonAllowedAt },
      );
    }
    swap.status = 'abandoned';
    await swap.save();
    const otherId = swap.participants.map(String).find((id) => id !== userId)!;
    await notificationService.notify({
      userId: otherId,
      type: 'swap_status_changed',
      title: 'Swap ended',
      body: 'A swap was abandoned',
      data: { swapId: String(swap._id), status: 'abandoned' },
    });
    return swap;
  },
};
