import type { Server as HttpServer } from 'http';
import { Server as SocketServer } from 'socket.io';
import { verifyAccessToken } from '../utils/jwt';
import { User } from '../models/user.model';
import { Conversation } from '../models/conversation.model';
import { bindSocketServer } from '../services/notification.service';
import { messagingService } from '../services/messaging.service';
import { env } from '../config/env';
import { logger } from '../utils/logger';

/**
 * Initializes the Socket.IO server on the `/realtime` namespace.
 * - Authenticates each connection via JWT (handshake `auth.token`).
 * - Joins the user's personal room `user:<id>` for realtime notifications.
 * - Chat message/typing/read events are added in US3 (task T049).
 */
export function initSocket(httpServer: HttpServer): SocketServer {
  const io = new SocketServer(httpServer, {
    cors: { origin: env.CORS_ORIGIN },
  });

  const realtime = io.of('/realtime');

  realtime.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth?.token as string | undefined;
      if (!token) return next(new Error('UNAUTHORIZED'));
      const payload = verifyAccessToken(token);
      const user = await User.findById(payload.sub).select('_id status');
      if (!user || user.status !== 'active') return next(new Error('UNAUTHORIZED'));
      socket.data.userId = String(user._id);
      next();
    } catch {
      next(new Error('UNAUTHORIZED'));
    }
  });

  realtime.on('connection', async (socket) => {
    const userId = socket.data.userId as string;
    socket.join(`user:${userId}`);

    // Join a room per conversation the user participates in.
    const conversations = await Conversation.find({ participants: userId }).select('_id');
    for (const c of conversations) socket.join(`conv:${String(c._id)}`);
    logger.debug(`socket connected: user=${userId}, conversations=${conversations.length}`);

    // Chat: send / edit / delete (broadcasts happen inside messaging.service).
    socket.on('message:send', async (payload, ack?: (r: unknown) => void) => {
      try {
        const msg = await messagingService.sendMessage(payload.conversationId, userId, {
          type: payload.type,
          body: payload.body,
          mediaUrl: payload.mediaUrl,
        });
        socket.join(`conv:${payload.conversationId}`);
        ack?.({ ok: true, clientMsgId: payload.clientMsgId, message: msg.toJSON() });
      } catch (err) {
        ack?.({ ok: false, error: (err as Error).message });
      }
    });

    socket.on('message:edit', async (payload, ack?: (r: unknown) => void) => {
      try {
        await messagingService.editMessage(payload.messageId, userId, payload.body);
        ack?.({ ok: true });
      } catch (err) {
        ack?.({ ok: false, error: (err as Error).message });
      }
    });

    socket.on('message:delete', async (payload, ack?: (r: unknown) => void) => {
      try {
        await messagingService.deleteMessage(payload.messageId, userId);
        ack?.({ ok: true });
      } catch (err) {
        ack?.({ ok: false, error: (err as Error).message });
      }
    });

    socket.on('message:read', async (payload) => {
      try {
        await messagingService.markRead(payload.conversationId, userId, payload.lastReadMessageId);
      } catch (err) {
        logger.debug('message:read failed', (err as Error).message);
      }
    });

    socket.on('typing:start', (payload) => {
      realtime.to(`conv:${payload.conversationId}`).emit('typing', {
        conversationId: payload.conversationId,
        userId,
        isTyping: true,
      });
    });

    socket.on('typing:stop', (payload) => {
      realtime.to(`conv:${payload.conversationId}`).emit('typing', {
        conversationId: payload.conversationId,
        userId,
        isTyping: false,
      });
    });

    socket.on('disconnect', () => {
      logger.debug(`socket disconnected: user=${userId}`);
    });
  });

  // Let the notification service emit to user rooms on this namespace.
  bindSocketServer(realtime);
  return io;
}
