import { Schema, model, Document, Types } from 'mongoose';

export type MessageType = 'text' | 'image' | 'audio' | 'video' | 'system';

export interface MessageDoc extends Document<Types.ObjectId> {
  _id: Types.ObjectId;
  conversation: Types.ObjectId;
  sender: Types.ObjectId;
  type: MessageType;
  body?: string;
  mediaUrl?: string;
  readBy: Types.ObjectId[];
  editedAt?: Date | null;
  deletedAt?: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

const messageSchema = new Schema<MessageDoc>(
  {
    conversation: { type: Schema.Types.ObjectId, ref: 'Conversation', required: true },
    sender: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    type: { type: String, enum: ['text', 'image', 'audio', 'video', 'system'], default: 'text' },
    body: { type: String, maxlength: 4000 },
    mediaUrl: { type: String },
    readBy: { type: [{ type: Schema.Types.ObjectId, ref: 'User' }], default: [] },
    editedAt: { type: Date, default: null },
    deletedAt: { type: Date, default: null },
  },
  { timestamps: true },
);

messageSchema.index({ conversation: 1, createdAt: -1 });

export const Message = model<MessageDoc>('Message', messageSchema);
