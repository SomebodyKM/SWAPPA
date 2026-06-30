import { RequestHandler } from 'express';
import { sessionService } from '../services/session.service';

export const sessionController: Record<string, RequestHandler> = {
  listMine: async (req, res) => {
    const q = (res.locals.query ?? {}) as { when?: 'upcoming' | 'past' };
    res.json({ items: await sessionService.listMine(req.auth!.userId, q.when ?? 'upcoming') });
  },

  read: async (req, res) => {
    res.json(await sessionService.getById(String(req.params.id), req.auth!.userId));
  },

  reschedule: async (req, res) => {
    const body = req.body as { scheduledAt?: string; format?: 'in_person' | 'remote' };
    res.json(
      await sessionService.reschedule(String(req.params.id), req.auth!.userId, {
        scheduledAt: body.scheduledAt ? new Date(body.scheduledAt) : undefined,
        format: body.format,
      }),
    );
  },

  cancel: async (req, res) => {
    res.json(await sessionService.cancel(String(req.params.id), req.auth!.userId));
  },

  respond: async (req, res) => {
    res.json(await sessionService.respond(String(req.params.id), req.auth!.userId, req.body.decision));
  },

  confirmComplete: async (req, res) => {
    res.json(await sessionService.confirmComplete(String(req.params.id), req.auth!.userId));
  },

  reportNoShow: async (req, res) => {
    res.json(await sessionService.reportNoShow(String(req.params.id), req.auth!.userId));
  },

  join: async (req, res) => {
    res.json(await sessionService.joinRemote(String(req.params.id), req.auth!.userId));
  },
};
