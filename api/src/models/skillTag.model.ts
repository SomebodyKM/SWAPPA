import { Schema, model, Document, Types } from 'mongoose';

export type SkillTagKind = 'offer' | 'want';
export type Proficiency = 'beginner' | 'intermediate' | 'advanced' | 'expert';

export interface SkillTagDoc extends Document<Types.ObjectId> {
  _id: Types.ObjectId;
  user: Types.ObjectId;
  skill: Types.ObjectId;
  kind: SkillTagKind;
  proficiency?: Proficiency; // required when kind === 'offer'
  createdAt: Date;
  updatedAt: Date;
}

const skillTagSchema = new Schema<SkillTagDoc>(
  {
    user: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    skill: { type: Schema.Types.ObjectId, ref: 'Skill', required: true },
    kind: { type: String, enum: ['offer', 'want'], required: true },
    proficiency: {
      type: String,
      enum: ['beginner', 'intermediate', 'advanced', 'expert'],
      required: function (this: SkillTagDoc) {
        return this.kind === 'offer';
      },
    },
  },
  { timestamps: true },
);

skillTagSchema.index({ user: 1, skill: 1, kind: 1 }, { unique: true });
skillTagSchema.index({ user: 1, kind: 1 });
skillTagSchema.index({ skill: 1, kind: 1 });

export const SkillTag = model<SkillTagDoc>('SkillTag', skillTagSchema);
