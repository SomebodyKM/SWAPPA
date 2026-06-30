import { Schema, model, Document, Types } from 'mongoose';

export type SessionFormat = 'in_person' | 'remote';
export type SessionStatus =
  | 'proposed'
  | 'accepted'
  | 'declined'
  | 'completed'
  | 'cancelled'
  | 'no_show';

export interface SessionDoc extends Document<Types.ObjectId> {
  _id: Types.ObjectId;
  swap: Types.ObjectId;
  teacher: Types.ObjectId;
  learner: Types.ObjectId;
  proposedBy: Types.ObjectId;
  scheduledAt: Date;
  format: SessionFormat;
  status: SessionStatus;
  confirmedBy: Types.ObjectId[]; // both required to mark completed (US4)
  rtcRoomId?: string | null; // remote sessions (US4)
  createdAt: Date;
  updatedAt: Date;
}

const sessionSchema = new Schema<SessionDoc>(
  {
    swap: { type: Schema.Types.ObjectId, ref: 'Swap', required: true },
    teacher: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    learner: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    proposedBy: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    scheduledAt: { type: Date, required: true },
    format: { type: String, enum: ['in_person', 'remote'], required: true },
    status: {
      type: String,
      enum: ['proposed', 'accepted', 'declined', 'completed', 'cancelled', 'no_show'],
      default: 'proposed',
    },
    confirmedBy: { type: [{ type: Schema.Types.ObjectId, ref: 'User' }], default: [] },
    rtcRoomId: { type: String, default: null },
  },
  { timestamps: true },
);

sessionSchema.index({ teacher: 1, scheduledAt: -1 });
sessionSchema.index({ learner: 1, scheduledAt: -1 });
sessionSchema.index({ swap: 1 });

export const Session = model<SessionDoc>('Session', sessionSchema);
