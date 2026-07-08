import { RequestHandler } from 'express';
import { swapService } from '../services/swap.service';
import { sessionService } from '../services/session.service';
import { SwapStatus } from '../models/swap.model';

export const swapController: Record<string, RequestHandler> = {
  list: async (req, res) => {
    const q = (res.locals.query ?? {}) as { status?: SwapStatus; partnerId?: string };
    res.json({ items: await swapService.listSwaps(req.auth!.userId, q.status, q.partnerId) });
  },

  read: async (req, res) => {
    res.json(await swapService.getSwap(String(req.params.id), req.auth!.userId));
  },

  create: async (req, res) => {
    const swap = await swapService.createSwap(req.auth!.userId, req.body);
    res.status(201).json(swap);
  },

  edit: async (req, res) => {
    res.json(await swapService.editSwap(String(req.params.id), req.auth!.userId, req.body));
  },

  withdraw: async (req, res) => {
    await swapService.withdrawSwap(String(req.params.id), req.auth!.userId);
    res.status(204).send();
  },

  accept: async (req, res) => {
    res.json(await swapService.acceptSwap(String(req.params.id), req.auth!.userId));
  },

  cancel: async (req, res) => {
    const body = req.body as { reason?: string };
    res.json(await swapService.cancelSwap(String(req.params.id), req.auth!.userId, body.reason));
  },

  finish: async (req, res) => {
    res.json(await swapService.confirmFinish(String(req.params.id), req.auth!.userId));
  },

  abandon: async (req, res) => {
    res.json(await swapService.abandonSwap(String(req.params.id), req.auth!.userId));
  },

  // Sessions nested under a swap
  proposeSession: async (req, res) => {
    const session = await sessionService.propose(String(req.params.id), req.auth!.userId, {
      teacherId: req.body.teacherId,
      learnerId: req.body.learnerId,
      scheduledAt: new Date(req.body.scheduledAt),
      format: req.body.format,
    });
    res.status(201).json(session);
  },

  listSessions: async (req, res) => {
    res.json({ items: await sessionService.listForSwap(String(req.params.id), req.auth!.userId) });
  },
};
