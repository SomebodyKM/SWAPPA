import { Schema, model, Document, Types } from 'mongoose';

export type SwapStatus = 'requested' | 'active' | 'completed' | 'cancelled' | 'abandoned';

/** Statuses that occupy an active-swap slot. */
export const ACTIVE_SWAP_STATUSES: SwapStatus[] = ['requested', 'active'];

export interface SwapDoc extends Document<Types.ObjectId> {
  _id: Types.ObjectId;
  participants: Types.ObjectId[]; // [initiator, partner]
  initiator: Types.ObjectId;
  partner: Types.ObjectId;
  offeredSkill: Types.ObjectId; // what the initiator teaches
  requestedSkill: Types.ObjectId; // what the initiator learns
  status: SwapStatus;
  conversation: Types.ObjectId;
  noShowReportedAt?: Date | null; // set when a session no-show is reported (US4)
  abandonAllowedAt?: Date | null; // earliest time the swap may be abandoned (US4)
  createdAt: Date;
  updatedAt: Date;
}

const swapSchema = new Schema<SwapDoc>(
  {
    participants: {
      type: [{ type: Schema.Types.ObjectId, ref: 'User' }],
      required: true,
    },
    initiator: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    partner: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    offeredSkill: { type: Schema.Types.ObjectId, ref: 'Skill', required: true },
    requestedSkill: { type: Schema.Types.ObjectId, ref: 'Skill', required: true },
    status: {
      type: String,
      enum: ['requested', 'active', 'completed', 'cancelled', 'abandoned'],
      default: 'requested',
    },
    conversation: { type: Schema.Types.ObjectId, ref: 'Conversation', required: true },
    noShowReportedAt: { type: Date, default: null },
    abandonAllowedAt: { type: Date, default: null },
  },
  { timestamps: true },
);

swapSchema.index({ participants: 1, status: 1 });

export const Swap = model<SwapDoc>('Swap', swapSchema);
