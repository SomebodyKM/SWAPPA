import { Schema, model, Document, Types } from 'mongoose';

export interface ReviewDoc extends Document<Types.ObjectId> {
  _id: Types.ObjectId;
  swap: Types.ObjectId;
  reviewer: Types.ObjectId;
  reviewee: Types.ObjectId;
  rating: number; // 1..5
  comment?: string;
  createdAt: Date;
  updatedAt: Date;
}

const reviewSchema = new Schema<ReviewDoc>(
  {
    swap: { type: Schema.Types.ObjectId, ref: 'Swap', required: true },
    reviewer: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    reviewee: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    rating: { type: Number, required: true, min: 1, max: 5 },
    comment: { type: String, maxlength: 1000 },
  },
  { timestamps: true },
);

reviewSchema.index({ swap: 1, reviewer: 1 }, { unique: true });
reviewSchema.index({ reviewee: 1, createdAt: -1 });

export const Review = model<ReviewDoc>('Review', reviewSchema);
