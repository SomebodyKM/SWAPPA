import { RequestHandler } from 'express';
import { notificationService } from '../services/notification.service';

export const notificationController: Record<string, RequestHandler> = {
  list: async (req, res) => {
    const q = (res.locals.query ?? {}) as { cursor?: string; limit?: number };
    res.json(await notificationService.list(req.auth!.userId, { cursor: q.cursor, limit: q.limit ?? 30 }));
  },

  markRead: async (req, res) => {
    await notificationService.markRead(req.auth!.userId, String(req.params.id));
    res.json({ status: 'ok' });
  },

  markAllRead: async (req, res) => {
    await notificationService.markAllRead(req.auth!.userId);
    res.json({ status: 'ok' });
  },

  remove: async (req, res) => {
    await notificationService.remove(req.auth!.userId, String(req.params.id));
    res.status(204).send();
  },
};
