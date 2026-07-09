import { Schema, model, Document, Types } from 'mongoose';
import { TIER_LIMITS, Tier } from '../config/limits';

export type UserRole = 'user' | 'admin';
export type UserStatus = 'active' | 'suspended' | 'banned';

export interface CreditsSub {
  basic: { balance: number; cap: number; lastRefillAt: Date };
  boost: { balance: number };
}

/**
 * Profile location. `point` is ALWAYS rounded to 2 decimal places (~1.1km) by
 * the server before storage, regardless of source (manual place lookup or
 * device auto-locate) — there is no path that stores street-level precision.
 * `precision: 'coarse'` documents that guarantee rather than offering a choice.
 */
export interface UserLocation {
  point?: { type: 'Point'; coordinates: [number, number] };
  placeId?: string; // Google place_id, when set via the manual picker
  displayName?: string; // e.g. "Camden, London" — shown in the UI
  precision: 'coarse';
  updatedAt?: Date;
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
  location?: UserLocation;
  tier: Tier;
  credits: CreditsSub;
  ratingAvg: number;
  ratingCount: number;
  onboardingComplete: boolean; // finished the post-signup profile + skills setup
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

const locationSchema = new Schema(
  {
    point: { type: pointSchema, required: false },
    placeId: { type: String },
    displayName: { type: String },
    precision: { type: String, enum: ['coarse'], default: 'coarse' },
    updatedAt: { type: Date },
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
    location: { type: locationSchema, required: false },
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
    onboardingComplete: { type: Boolean, default: false },
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
userSchema.index({ 'location.point': '2dsphere' });

// Never leak the password hash in JSON responses.
userSchema.set('toJSON', {
  transform(_doc: any, ret: any) {
    delete ret.passwordHash;
    delete ret.__v;
    return ret;
  },
});

export const User = model<UserDoc>('User', userSchema);
