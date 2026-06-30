import { RequestHandler } from 'express';
import { creditService } from '../services/credit.service';
import { BOOST_PACKS } from '../config/limits';

export const creditController: Record<string, RequestHandler> = {
  balance: async (req, res) => {
    res.json(await creditService.getBalance(req.auth!.userId));
  },

  transactions: async (req, res) => {
    const q = (res.locals.query ?? {}) as { cursor?: string; limit?: number };
    res.json(
      await creditService.listTransactions(req.auth!.userId, { cursor: q.cursor, limit: q.limit ?? 20 }),
    );
  },

  // Display-only catalog; purchases happen via RevenueCat and are credited by the webhook (US7).
  packs: async (_req, res) => {
    res.json({
      items: Object.entries(BOOST_PACKS).map(([productId, credits]) => ({ productId, credits })),
    });
  },
};
