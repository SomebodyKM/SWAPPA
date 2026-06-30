import { RequestHandler } from 'express';
import { subscriptionService } from '../services/subscription.service';

export const subscriptionController: Record<string, RequestHandler> = {
  get: async (req, res) => {
    res.json(await subscriptionService.getForUser(req.auth!.userId));
  },

  // Display offerings; the actual purchase happens in-app via RevenueCat.
  offerings: async (_req, res) => {
    res.json({
      items: [
        {
          entitlement: 'premium',
          description: 'Unlock wider reach, full results, multimedia chat, more swaps & a larger credit cap.',
        },
      ],
    });
  },

  // Server-to-server webhook (no JWT; shared-secret via webhookAuth).
  webhook: async (req, res) => {
    const event = req.body?.event;
    if (event?.type && event?.app_user_id) {
      await subscriptionService.handleEvent(event);
    }
    res.json({ status: 'ok' });
  },
};
