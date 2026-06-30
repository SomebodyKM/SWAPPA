import { Schema, model, Document, Types } from 'mongoose';

export type SkillStatus = 'approved' | 'pending';

export interface SkillDoc extends Document<Types.ObjectId> {
  _id: Types.ObjectId;
  name: string;
  nameNormalized: string; // lowercased/trimmed for uniqueness + lookups
  category: string;
  aliases: string[];
  status: SkillStatus; // user-proposed skills start 'pending' (admin approves — US9)
  createdAt: Date;
  updatedAt: Date;
}

export function normalizeSkillName(name: string): string {
  return name.trim().toLowerCase();
}

const skillSchema = new Schema<SkillDoc>(
  {
    name: { type: String, required: true, trim: true, maxlength: 80 },
    nameNormalized: { type: String, required: true },
    category: { type: String, required: true, trim: true, maxlength: 60 },
    aliases: { type: [String], default: [] },
    status: { type: String, enum: ['approved', 'pending'], default: 'approved' },
  },
  { timestamps: true },
);

skillSchema.index({ nameNormalized: 1 }, { unique: true });
skillSchema.index({ category: 1 });
skillSchema.index({ name: 'text', aliases: 'text' });

export const Skill = model<SkillDoc>('Skill', skillSchema);
