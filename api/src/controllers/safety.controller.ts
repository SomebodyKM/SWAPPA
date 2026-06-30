import { RequestHandler } from 'express';
import { safetyService } from '../services/safety.service';

export const safetyController: Record<string, RequestHandler> = {
  report: async (req, res) => {
    const r = await safetyService.report(req.auth!.userId, req.body.targetUserId, req.body.reason);
    res.status(201).json(r);
  },

  block: async (req, res) => {
    const r = await safetyService.block(req.auth!.userId, req.body.targetUserId);
    res.status(201).json(r);
  },

  unblock: async (req, res) => {
    await safetyService.unblock(req.auth!.userId, String(req.params.targetUserId));
    res.status(204).send();
  },

  listBlocks: async (req, res) => {
    res.json({ items: await safetyService.listBlocks(req.auth!.userId) });
  },
};
