import { Schema, model, Document, Types } from 'mongoose';
import { Tier } from '../config/limits';

export type SubscriptionStatus = 'active' | 'expired' | 'cancelled' | 'grace';

export interface SubscriptionDoc extends Document<Types.ObjectId> {
  _id: Types.ObjectId;
  user: Types.ObjectId;
  tier: Tier;
  productId?: string | null;
  entitlement?: string | null;
  status: SubscriptionStatus;
  currentPeriodEnd?: Date | null;
  lastEventId?: string | null;
  createdAt: Date;
  updatedAt: Date;
}

const subscriptionSchema = new Schema<SubscriptionDoc>(
  {
    user: { type: Schema.Types.ObjectId, ref: 'User', required: true, unique: true },
    tier: { type: String, enum: ['free', 'premium'], default: 'free' },
    productId: { type: String, default: null },
    entitlement: { type: String, default: null },
    status: { type: String, enum: ['active', 'expired', 'cancelled', 'grace'], default: 'expired' },
    currentPeriodEnd: { type: Date, default: null },
    lastEventId: { type: String, default: null },
  },
  { timestamps: true },
);

export const Subscription = model<SubscriptionDoc>('Subscription', subscriptionSchema);
