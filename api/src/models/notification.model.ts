import { Schema, model, Document, Types } from 'mongoose';

export interface NotificationDoc extends Document<Types.ObjectId> {
  user: Types.ObjectId;
  type: string; // e.g. message_received, swap_status_changed (see websocket-events.md)
  title: string;
  body: string;
  data: Record<string, unknown>;
  read: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const notificationSchema = new Schema<NotificationDoc>(
  {
    user: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    type: { type: String, required: true },
    title: { type: String, default: '' },
    body: { type: String, default: '' },
    data: { type: Schema.Types.Mixed, default: {} },
    read: { type: Boolean, default: false },
  },
  { timestamps: true },
);

notificationSchema.index({ user: 1, createdAt: -1 });

export const Notification = model<NotificationDoc>('Notification', notificationSchema);
