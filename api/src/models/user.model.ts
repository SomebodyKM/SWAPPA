import { Schema, model, Document, Types } from 'mongoose';
import { TIER_LIMITS, Tier } from '../config/limits';

export type UserRole = 'user' | 'admin';
export type UserStatus = 'active' | 'suspended' | 'banned';
export type LocationPrecision = 'approximate' | 'precise';

export interface CreditsSub {
  basic: { balance: number; cap: number; lastRefillAt: Date };
  boost: { balance: number };
}

export interface UserDoc extends Document<Types.ObjectId> {
  _id: Types.ObjectId;
  email?: string;
  phone?: string;
  passwordHash: string;
  emailVerified: boolean;
  phoneVerified: boolean; // reserved for future phone verification
  verifiedAt?: Date | null;
  displayName: string;
  photoUrl?: string;
  bio?: string;
  location?: { type: 'Point'; coordinates: [number, number] };
  locationPrecision: LocationPrecision;
  tier: Tier;
  credits: CreditsSub;
  ratingAvg: number;
  ratingCount: number;
  welcomeGrantApplied: boolean;
  deviceFingerprints: string[];
  pushTokens: string[];
  role: UserRole;
  status: UserStatus;
  banReason?: string | null;
  bannedAt?: Date | null;
  bannedBy?: Types.ObjectId | null;
  createdAt: Date;
  updatedAt: Date;
}

const pointSchema = new Schema(
  {
    type: { type: String, enum: ['Point'], required: true },
    coordinates: { type: [Number], required: true }, // [lng, lat]
  },
  { _id: false },
);

const userSchema = new Schema<UserDoc>(
  {
    email: { type: String, lowercase: true, trim: true },
    phone: { type: String, trim: true },
    passwordHash: { type: String, required: true, select: false },
    emailVerified: { type: Boolean, default: false },
    phoneVerified: { type: Boolean, default: false },
    verifiedAt: { type: Date, default: null },
    displayName: { type: String, required: true, trim: true, maxlength: 80 },
    photoUrl: { type: String },
    bio: { type: String, maxlength: 500 },
    location: { type: pointSchema, required: false },
    locationPrecision: {
      type: String,
      enum: ['approximate', 'precise'],
      default: 'approximate',
    },
    tier: { type: String, enum: ['free', 'premium'], default: 'free' },
    credits: {
      basic: {
        balance: { type: Number, default: 0, min: 0 },
        cap: { type: Number, default: TIER_LIMITS.free.basicCreditCap },
        lastRefillAt: { type: Date, default: () => new Date() },
      },
      boost: {
        balance: { type: Number, default: 0, min: 0 },
      },
    },
    ratingAvg: { type: Number, default: 0 },
    ratingCount: { type: Number, default: 0 },
    welcomeGrantApplied: { type: Boolean, default: false },
    deviceFingerprints: { type: [String], default: [] },
    pushTokens: { type: [String], default: [] },
    role: { type: String, enum: ['user', 'admin'], default: 'user' },
    status: { type: String, enum: ['active', 'suspended', 'banned'], default: 'active' },
    banReason: { type: String, default: null },
    bannedAt: { type: Date, default: null },
    bannedBy: { type: Schema.Types.ObjectId, ref: 'User', default: null },
  },
  { timestamps: true },
);

// Indexes (data-model.md)
userSchema.index({ email: 1 }, { unique: true, sparse: true });
userSchema.index({ phone: 1 }, { unique: true, sparse: true });
userSchema.index({ location: '2dsphere' });

// Never leak the password hash in JSON responses.
userSchema.set('toJSON', {
  transform(_doc: any, ret: any) {
    delete ret.passwordHash;
    delete ret.__v;
    return ret;
  },
});

export const User = model<UserDoc>('User', userSchema);
