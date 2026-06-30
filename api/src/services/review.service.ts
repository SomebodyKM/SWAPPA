import { Types } from 'mongoose';
import { Review, ReviewDoc } from '../models/review.model';
import { Swap } from '../models/swap.model';
import { User } from '../models/user.model';
import { notificationService } from './notification.service';
import { ANTI_SPAM } from '../config/limits';
import { Errors } from '../utils/errors';

async function recomputeRating(userId: Types.ObjectId): Promise<void> {
  const stats = await Review.aggregate<{ avg: number; count: number }>([
    { $match: { reviewee: userId } },
    { $group: { _id: null, avg: { $avg: '$rating' }, count: { $sum: 1 } } },
  ]);
  const avg = stats[0]?.avg ?? 0;
  const count = stats[0]?.count ?? 0;
  await User.updateOne(
    { _id: userId },
    { ratingAvg: Math.round(avg * 100) / 100, ratingCount: count },
  );
}

export const reviewService = {
  /** Create a review — only after a completed swap, only by a participant (FR-033). */
  async create(
    swapId: string,
    reviewerId: string,
    input: { rating: number; comment?: string },
  ): Promise<ReviewDoc> {
    const swap = await Swap.findById(swapId);
    if (!swap) throw Errors.notFound('Swap not found');
    if (!swap.participants.some((p) => String(p) === reviewerId)) {
      throw Errors.forbidden('Not a participant of this swap');
    }
    if (swap.status !== 'completed') {
      throw Errors.conflict('You can only review after a completed swap', 'SWAP_NOT_COMPLETED');
    }
    const revieweeId = swap.participants.map(String).find((id) => id !== reviewerId)!;

    let review: ReviewDoc;
    try {
      review = await Review.create({
        swap: swapId,
        reviewer: reviewerId,
        reviewee: revieweeId,
        rating: input.rating,
        comment: input.comment,
      });
    } catch (err) {
      if ((err as { code?: number }).code === 11000) {
        throw Errors.conflict('You have already reviewed this swap', 'ALREADY_REVIEWED');
      }
      throw err;
    }

    await recomputeRating(new Types.ObjectId(revieweeId));
    await notificationService.notify({
      userId: revieweeId,
      type: 'review_received',
      title: 'New review',
      body: `You received a ${input.rating}-star review`,
      data: { reviewId: String(review._id), fromUserId: reviewerId, rating: input.rating },
    });
    return review;
  },

  async edit(
    reviewId: string,
    userId: string,
    input: { rating?: number; comment?: string },
  ): Promise<ReviewDoc> {
    const review = await Review.findById(reviewId);
    if (!review) throw Errors.notFound('Review not found');
    if (String(review.reviewer) !== userId) throw Errors.forbidden('You can only edit your own review');
    if (Date.now() - review.createdAt.getTime() > ANTI_SPAM.reviewEditWindowHours * 3600_000) {
      throw Errors.badRequest('Review edit window has expired', { code: 'EDIT_WINDOW_EXPIRED' });
    }
    if (input.rating !== undefined) review.rating = input.rating;
    if (input.comment !== undefined) review.comment = input.comment;
    await review.save();
    await recomputeRating(review.reviewee);
    return review;
  },

  async remove(reviewId: string, userId: string): Promise<void> {
    const review = await Review.findById(reviewId);
    if (!review) throw Errors.notFound('Review not found');
    if (String(review.reviewer) !== userId) throw Errors.forbidden('You can only delete your own review');
    if (Date.now() - review.createdAt.getTime() > ANTI_SPAM.reviewEditWindowHours * 3600_000) {
      throw Errors.badRequest('Review edit window has expired', { code: 'EDIT_WINDOW_EXPIRED' });
    }
    const revieweeId = review.reviewee;
    await Review.deleteOne({ _id: reviewId });
    await recomputeRating(revieweeId);
  },

  async listForUser(
    userId: string,
    opts: { cursor?: string; limit: number },
  ): Promise<{ items: ReviewDoc[]; nextCursor: string | null }> {
    const filter: Record<string, unknown> = { reviewee: userId };
    if (opts.cursor) filter._id = { $lt: new Types.ObjectId(opts.cursor) };
    const docs = await Review.find(filter)
      .sort({ _id: -1 })
      .limit(opts.limit + 1)
      .populate('reviewer', 'displayName photoUrl');
    const hasMore = docs.length > opts.limit;
    const items = hasMore ? docs.slice(0, opts.limit) : docs;
    return { items, nextCursor: hasMore ? String(items[items.length - 1]._id) : null };
  },

  async getById(reviewId: string): Promise<ReviewDoc> {
    const review = await Review.findById(reviewId).populate('reviewer', 'displayName photoUrl');
    if (!review) throw Errors.notFound('Review not found');
    return review;
  },
};
