import type { Namespace } from 'socket.io';
import { Types } from 'mongoose';
import { Notification } from '../models/notification.model';
import { User } from '../models/user.model';
import { pushService } from './notifiers/push';
import { logger } from '../utils/logger';

/**
 * Delivers realtime notifications: persists to the feed, emits over Socket.IO to
 * the user's room when online, and (future) falls back to FCM push when offline.
 * The `/realtime` namespace is injected at bootstrap to avoid a circular import.
 */
let realtime: Namespace | null = null;

export function bindSocketServer(nsp: Namespace): void {
  realtime = nsp;
}

/** Emit a realtime event to an arbitrary room (e.g. a conversation room). No-op if offline. */
export function emitToRoom(room: string, event: string, payload: unknown): void {
  if (realtime) realtime.to(room).emit(event, payload);
}

/** Whether at least one socket is present in a room. */
export function roomHasMembers(room: string): boolean {
  return realtime ? (realtime.adapter.rooms.get(room)?.size ?? 0) > 0 : false;
}

export interface NotifyInput {
  userId: string;
  type: string;
  title?: string;
  body?: string;
  data?: Record<string, unknown>;
}

export const notificationService = {
  async notify(input: NotifyInput): Promise<void> {
    const doc = await Notification.create({
      user: input.userId,
      type: input.type,
      title: input.title ?? '',
      body: input.body ?? '',
      data: input.data ?? {},
    });

    const payload = {
      id: String(doc._id),
      type: doc.type,
      title: doc.title,
      body: doc.body,
      data: doc.data,
      createdAt: doc.createdAt,
    };

    const room = `user:${input.userId}`;
    const online = realtime ? (realtime.adapter.rooms.get(room)?.size ?? 0) > 0 : false;

    if (realtime && online) {
      realtime.to(room).emit('notification', payload);
    } else {
      // Offline: fall back to FCM push.
      const user = await User.findById(input.userId).select('pushTokens');
      if (user?.pushTokens?.length) {
        await pushService.send(user.pushTokens, {
          title: doc.title || 'SWAPPA',
          body: doc.body,
          data: { type: doc.type, notificationId: String(doc._id) },
        });
      } else {
        logger.debug(`[notify] user ${input.userId} offline with no push tokens`);
      }
    }
  },

  async list(userId: string, opts: { cursor?: string; limit: number }) {
    const filter: Record<string, unknown> = { user: userId };
    if (opts.cursor) filter._id = { $lt: new Types.ObjectId(opts.cursor) };
    const docs = await Notification.find(filter).sort({ _id: -1 }).limit(opts.limit + 1);
    const hasMore = docs.length > opts.limit;
    const items = hasMore ? docs.slice(0, opts.limit) : docs;
    return { items, nextCursor: hasMore ? String(items[items.length - 1]._id) : null };
  },

  async markRead(userId: string, notificationId: string): Promise<void> {
    await Notification.updateOne({ _id: notificationId, user: userId }, { read: true });
  },

  async markAllRead(userId: string): Promise<void> {
    await Notification.updateMany({ user: userId, read: false }, { read: true });
  },

  async remove(userId: string, notificationId: string): Promise<void> {
    await Notification.deleteOne({ _id: notificationId, user: userId });
  },
};
