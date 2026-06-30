import { Schema, model, Document, Types } from 'mongoose';

export type CreditTxType = 'grant' | 'refill' | 'spend' | 'purchase' | 'refund';
export type CreditTxAction = 'icebreaker' | 'insight' | 'rematch' | 'profile_opt' | null;

export interface CreditTransactionDoc extends Document<Types.ObjectId> {
  _id: Types.ObjectId;
  user: Types.ObjectId;
  type: CreditTxType;
  action: CreditTxAction;
  basicDelta: number;
  boostDelta: number;
  basicAfter: number;
  boostAfter: number;
  refId: string; // idempotency key (AI request id, RevenueCat txn/event id, refill cycle key)
  note?: string;
  createdAt: Date;
  updatedAt: Date;
}

const creditTransactionSchema = new Schema<CreditTransactionDoc>(
  {
    user: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    type: { type: String, enum: ['grant', 'refill', 'spend', 'purchase', 'refund'], required: true },
    action: {
      type: String,
      enum: ['icebreaker', 'insight', 'rematch', 'profile_opt', null],
      default: null,
    },
    basicDelta: { type: Number, default: 0 },
    boostDelta: { type: Number, default: 0 },
    basicAfter: { type: Number, required: true },
    boostAfter: { type: Number, required: true },
    refId: { type: String, required: true },
    note: { type: String },
  },
  { timestamps: true },
);

// Append-only + idempotent: a (refId, type) pair can be applied at most once.
creditTransactionSchema.index({ refId: 1, type: 1 }, { unique: true });
creditTransactionSchema.index({ user: 1, createdAt: -1 });

export const CreditTransaction = model<CreditTransactionDoc>(
  'CreditTransaction',
  creditTransactionSchema,
);
