import { Schema, model, Document, Types } from 'mongoose';

export interface ConversationDoc extends Document<Types.ObjectId> {
  _id: Types.ObjectId;
  participants: Types.ObjectId[]; // exactly 2
  pairKey: string; // sorted "idA:idB" — uniqueness for the participant pair
  lastMessageAt?: Date;
  lastMessagePreview?: string;
  createdAt: Date;
  updatedAt: Date;
}

const conversationSchema = new Schema<ConversationDoc>(
  {
    participants: {
      type: [{ type: Schema.Types.ObjectId, ref: 'User' }],
      required: true,
      validate: [(v: unknown[]) => v.length === 2, 'A conversation must have exactly 2 participants'],
    },
    pairKey: { type: String, required: true },
    lastMessageAt: { type: Date },
    lastMessagePreview: { type: String },
  },
  { timestamps: true },
);

conversationSchema.index({ pairKey: 1 }, { unique: true });
conversationSchema.index({ participants: 1, lastMessageAt: -1 });

/** Stable key for a participant pair regardless of order. */
export function pairKeyFor(a: string, b: string): string {
  return [a, b].sort().join(':');
}

export const Conversation = model<ConversationDoc>('Conversation', conversationSchema);
