import crypto from 'crypto';
import { Types } from 'mongoose';
import { Session, SessionDoc, SessionFormat } from '../models/session.model';
import { Swap } from '../models/swap.model';
import { notificationService } from './notification.service';
import { swapService } from './swap.service';
import { Errors } from '../utils/errors';

async function loadSwapForParticipant(swapId: string, userId: string) {
  const swap = await Swap.findById(swapId);
  if (!swap) throw Errors.notFound('Swap not found');
  if (!swap.participants.some((p) => String(p) === userId)) {
    throw Errors.forbidden('Not a participant of this swap');
  }
  return swap;
}

async function loadSessionForParticipant(sessionId: string, userId: string): Promise<SessionDoc> {
  const session = await Session.findById(sessionId);
  if (!session) throw Errors.notFound('Session not found');
  const isParty = [String(session.teacher), String(session.learner)].includes(userId);
  if (!isParty) throw Errors.forbidden('Not a participant of this session');
  return session;
}

export const sessionService = {
  async propose(
    swapId: string,
    userId: string,
    input: { teacherId: string; learnerId: string; scheduledAt: Date; format: SessionFormat },
  ): Promise<SessionDoc> {
    const swap = await loadSwapForParticipant(swapId, userId);
    if (swap.status !== 'active') throw Errors.conflict('Swap must be active to schedule sessions');

    const partySet = new Set(swap.participants.map(String));
    if (!partySet.has(input.teacherId) || !partySet.has(input.learnerId)) {
      throw Errors.badRequest('Teacher and learner must be the swap participants');
    }
    if (input.teacherId === input.learnerId) throw Errors.badRequest('Teacher and learner must differ');
    if (input.scheduledAt.getTime() <= Date.now()) {
      throw Errors.badRequest('Scheduled time must be in the future');
    }

    const session = await Session.create({
      swap: swapId,
      teacher: input.teacherId,
      learner: input.learnerId,
      proposedBy: userId,
      scheduledAt: input.scheduledAt,
      format: input.format,
      status: 'proposed',
    });

    const otherId = [...partySet].find((id) => id !== userId)!;
    await notificationService.notify({
      userId: otherId,
      type: 'session_proposed',
      title: 'Session proposed',
      body: 'A learning session has been proposed',
      data: { sessionId: String(session._id), swapId, scheduledAt: input.scheduledAt },
    });
    return session;
  },

  async respond(
    sessionId: string,
    userId: string,
    decision: 'accept' | 'decline',
  ): Promise<SessionDoc> {
    const session = await loadSessionForParticipant(sessionId, userId);
    if (String(session.proposedBy) === userId) {
      throw Errors.forbidden('The proposer cannot respond to their own proposal');
    }
    if (session.status !== 'proposed') throw Errors.conflict('Session is not awaiting a response');

    session.status = decision === 'accept' ? 'accepted' : 'declined';
    await session.save();
    await notificationService.notify({
      userId: String(session.proposedBy),
      type: 'session_responded',
      title: `Session ${session.status}`,
      body: `Your session proposal was ${session.status}`,
      data: { sessionId: String(session._id), decision },
    });
    return session;
  },

  async reschedule(
    sessionId: string,
    userId: string,
    input: { scheduledAt?: Date; format?: SessionFormat },
  ): Promise<SessionDoc> {
    const session = await loadSessionForParticipant(sessionId, userId);
    if (['completed', 'cancelled', 'no_show'].includes(session.status)) {
      throw Errors.conflict('Session can no longer be changed');
    }
    if (input.scheduledAt) {
      if (input.scheduledAt.getTime() <= Date.now()) {
        throw Errors.badRequest('Scheduled time must be in the future');
      }
      session.scheduledAt = input.scheduledAt;
    }
    if (input.format) session.format = input.format;
    // A reschedule re-opens the proposal for the other party to confirm.
    session.status = 'proposed';
    session.proposedBy = new Types.ObjectId(userId);
    await session.save();
    return session;
  },

  async cancel(sessionId: string, userId: string): Promise<SessionDoc> {
    const session = await loadSessionForParticipant(sessionId, userId);
    if (['completed', 'cancelled'].includes(session.status)) {
      throw Errors.conflict('Session cannot be cancelled');
    }
    session.status = 'cancelled';
    await session.save();
    return session;
  },

  async listMine(userId: string, when: 'upcoming' | 'past'): Promise<SessionDoc[]> {
    const now = new Date();
    const timeFilter =
      when === 'upcoming' ? { scheduledAt: { $gte: now } } : { scheduledAt: { $lt: now } };
    return Session.find({
      $and: [{ $or: [{ teacher: userId }, { learner: userId }] }, timeFilter],
    }).sort({ scheduledAt: when === 'upcoming' ? 1 : -1 });
  },

  async listForSwap(swapId: string, userId: string): Promise<SessionDoc[]> {
    await loadSwapForParticipant(swapId, userId);
    return Session.find({ swap: swapId }).sort({ scheduledAt: -1 });
  },

  async getById(sessionId: string, userId: string): Promise<SessionDoc> {
    return loadSessionForParticipant(sessionId, userId);
  },

  /**
   * Confirm a session as completed. When BOTH parties confirm, the session is
   * completed and the parent swap is marked completed (releasing the slot) — FR-012.
   */
  async confirmComplete(sessionId: string, userId: string): Promise<SessionDoc> {
    const session = await loadSessionForParticipant(sessionId, userId);
    if (!['accepted', 'completed'].includes(session.status)) {
      throw Errors.conflict('Only an accepted session can be confirmed complete');
    }
    if (!session.confirmedBy.some((id) => String(id) === userId)) {
      session.confirmedBy.push(new Types.ObjectId(userId));
    }
    const bothConfirmed =
      session.confirmedBy.some((id) => String(id) === String(session.teacher)) &&
      session.confirmedBy.some((id) => String(id) === String(session.learner));

    if (bothConfirmed && session.status !== 'completed') {
      session.status = 'completed';
      await session.save();
      const swap = await swapService.markCompleted(String(session.swap));
      await Promise.all(
        swap.participants.map((p) =>
          notificationService.notify({
            userId: String(p),
            type: 'session_completed',
            title: 'Swap complete',
            body: 'Your session is complete — leave a review!',
            data: { sessionId: String(session._id), swapId: String(session.swap) },
          }),
        ),
      );
    } else {
      await session.save();
    }
    return session;
  },

  /**
   * Report that the other party did not show. Allowed only after the scheduled time.
   * Marks the session `no_show` and starts the swap's abandon grace window (FR-038).
   */
  async reportNoShow(sessionId: string, userId: string): Promise<SessionDoc> {
    const session = await loadSessionForParticipant(sessionId, userId);
    if (session.scheduledAt.getTime() > Date.now()) {
      throw Errors.badRequest('Cannot report a no-show before the scheduled time');
    }
    if (!['accepted', 'proposed'].includes(session.status)) {
      throw Errors.conflict('Session is not in a state where a no-show can be reported');
    }
    session.status = 'no_show';
    await session.save();
    await swapService.recordNoShow(String(session.swap));

    const otherId = [String(session.teacher), String(session.learner)].find((id) => id !== userId)!;
    await notificationService.notify({
      userId: otherId,
      type: 'no_show_reported',
      title: 'No-show reported',
      body: 'A no-show was reported for your session',
      data: { sessionId: String(session._id), swapId: String(session.swap) },
    });
    return session;
  },

  /**
   * Mint a short-lived join token for a remote session. The RTC provider is not yet
   * finalized (Agora/LiveKit — analysis A2); this returns a placeholder token that the
   * provider integration will replace without changing the contract.
   */
  async joinRemote(
    sessionId: string,
    userId: string,
  ): Promise<{ rtcRoomId: string; token: string; expiresAt: Date }> {
    const session = await loadSessionForParticipant(sessionId, userId);
    if (session.format !== 'remote') throw Errors.badRequest('This session is not remote');
    if (!['accepted'].includes(session.status)) {
      throw Errors.conflict('Session must be accepted to join');
    }
    if (!session.rtcRoomId) {
      session.rtcRoomId = `swappa-${String(session._id)}`;
      await session.save();
    }
    const token = crypto.randomBytes(24).toString('hex'); // placeholder until RTC provider chosen
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000);
    return { rtcRoomId: session.rtcRoomId, token, expiresAt };
  },
};
