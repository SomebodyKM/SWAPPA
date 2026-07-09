import { RequestHandler } from 'express';
import { messagingService } from '../services/messaging.service';

export const messagingController: Record<string, RequestHandler> = {
  listConversations: async (req, res) => {
    res.json({ items: await messagingService.listConversations(req.auth!.userId) });
  },

  createConversation: async (req, res) => {
    const conv = await messagingService.getOrCreateConversation(req.auth!.userId, req.body.targetUserId);
    await conv.populate('participants', 'displayName photoUrl ratingAvg');
    res.status(201).json(conv);
  },

  getConversation: async (req, res) => {
    const conv = await messagingService.getConversation(String(req.params.id), req.auth!.userId);
    res.json(conv);
  },

  listMessages: async (req, res) => {
    const q = (res.locals.query ?? {}) as { cursor?: string; limit?: number };
    const page = await messagingService.listMessages(String(req.params.id), req.auth!.userId, {
      cursor: q.cursor,
      limit: q.limit ?? 30,
    });
    res.json(page);
  },

  sendMessage: async (req, res) => {
    const msg = await messagingService.sendMessage(String(req.params.id), req.auth!.userId, req.body);
    res.status(201).json(msg);
  },

  getMessage: async (req, res) => {
    res.json(await messagingService.getMessage(String(req.params.id), req.auth!.userId));
  },

  editMessage: async (req, res) => {
    const msg = await messagingService.editMessage(
      String(req.params.id),
      req.auth!.userId,
      req.body.body,
    );
    res.json(msg);
  },

  deleteMessage: async (req, res) => {
    await messagingService.deleteMessage(String(req.params.id), req.auth!.userId);
    res.status(204).send();
  },
};
