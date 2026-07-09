import { RequestHandler } from 'express';
import { reviewService } from '../services/review.service';

export const reviewController: Record<string, RequestHandler> = {
  create: async (req, res) => {
    const review = await reviewService.create(String(req.params.id), req.auth!.userId, {
      rating: req.body.rating,
      comment: req.body.comment,
    });
    res.status(201).json(review);
  },

  mine: async (req, res) => {
    const review = await reviewService.findMine(String(req.params.id), req.auth!.userId);
    res.json({ review });
  },

  listForUser: async (req, res) => {
    const q = (res.locals.query ?? {}) as { cursor?: string; limit?: number };
    res.json(
      await reviewService.listForUser(String(req.params.id), {
        cursor: q.cursor,
        limit: q.limit ?? 20,
      }),
    );
  },

  read: async (req, res) => {
    res.json(await reviewService.getById(String(req.params.id)));
  },

  edit: async (req, res) => {
    res.json(await reviewService.edit(String(req.params.id), req.auth!.userId, req.body));
  },

  remove: async (req, res) => {
    await reviewService.remove(String(req.params.id), req.auth!.userId);
    res.status(204).send();
  },
};
