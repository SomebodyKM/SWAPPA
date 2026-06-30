import { Schema, model, Document, Types } from 'mongoose';

export type VerificationChannel = 'email' | 'phone';

export interface VerificationDoc extends Document<Types.ObjectId> {
  user: Types.ObjectId;
  channel: VerificationChannel; // 'email' for v1; 'phone' reserved for future
  target: string; // the email address (or phone) the code was sent to
  codeHash: string; // hashed OTP — never store the raw code
  expiresAt: Date;
  attempts: number;
  lastSentAt: Date;
  consumedAt?: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

const verificationSchema = new Schema<VerificationDoc>(
  {
    user: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    channel: { type: String, enum: ['email', 'phone'], required: true },
    target: { type: String, required: true },
    codeHash: { type: String, required: true },
    expiresAt: { type: Date, required: true },
    attempts: { type: Number, default: 0 },
    lastSentAt: { type: Date, default: () => new Date() },
    consumedAt: { type: Date, default: null },
  },
  { timestamps: true },
);

// Auto-purge expired/old challenges (TTL on expiresAt).
verificationSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });
verificationSchema.index({ user: 1, channel: 1 });

export const Verification = model<VerificationDoc>('Verification', verificationSchema);
