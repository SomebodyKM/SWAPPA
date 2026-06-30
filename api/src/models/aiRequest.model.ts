import { Schema, model, Document, Types } from 'mongoose';
import { AiAction } from '../config/limits';

export type AIRequestState = 'reserved' | 'succeeded' | 'failed';

export interface AIRequestDoc extends Document<Types.ObjectId> {
  _id: Types.ObjectId;
  user: Types.ObjectId;
  action: AiAction;
  cost: number;
  state: AIRequestState;
  targetRef?: Types.ObjectId | null;
  outputRef?: string | null;
  createdAt: Date;
  updatedAt: Date;
}

const aiRequestSchema = new Schema<AIRequestDoc>(
  {
    user: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    action: { type: String, enum: ['icebreaker', 'insight', 'rematch', 'profile_opt'], required: true },
    cost: { type: Number, required: true },
    state: { type: String, enum: ['reserved', 'succeeded', 'failed'], default: 'reserved' },
    targetRef: { type: Schema.Types.ObjectId, default: null },
    outputRef: { type: String, default: null },
  },
  { timestamps: true },
);

aiRequestSchema.index({ user: 1, createdAt: -1 });

export const AIRequest = model<AIRequestDoc>('AIRequest', aiRequestSchema);
