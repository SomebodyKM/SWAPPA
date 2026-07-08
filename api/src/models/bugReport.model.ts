import { Schema, model, Document, Types } from 'mongoose';

export type BugReportStatus = 'open' | 'resolved' | 'dismissed';

export interface BugReportDoc extends Document<Types.ObjectId> {
  _id: Types.ObjectId;
  reporter: Types.ObjectId;
  description: string;
  status: BugReportStatus;
  resolvedBy?: Types.ObjectId | null;
  resolutionNote?: string | null;
  createdAt: Date;
  updatedAt: Date;
}

const bugReportSchema = new Schema<BugReportDoc>(
  {
    reporter: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    description: { type: String, required: true, maxlength: 2000 },
    status: { type: String, enum: ['open', 'resolved', 'dismissed'], default: 'open' },
    resolvedBy: { type: Schema.Types.ObjectId, ref: 'User', default: null },
    resolutionNote: { type: String, default: null },
  },
  { timestamps: true },
);

bugReportSchema.index({ reporter: 1, createdAt: -1 });
bugReportSchema.index({ status: 1, createdAt: -1 });

export const BugReport = model<BugReportDoc>('BugReport', bugReportSchema);
