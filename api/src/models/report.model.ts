import { Schema, model, Document, Types } from 'mongoose';

export type ReportKind = 'report' | 'block';
export type ReportStatus = 'open' | 'reviewing' | 'resolved' | 'dismissed';

export interface ReportDoc extends Document<Types.ObjectId> {
  _id: Types.ObjectId;
  reporter: Types.ObjectId;
  target: Types.ObjectId;
  kind: ReportKind;
  reason?: string;
  status: ReportStatus; // reports only; managed by admin
  resolvedBy?: Types.ObjectId | null;
  resolutionNote?: string | null;
  createdAt: Date;
  updatedAt: Date;
}

const reportSchema = new Schema<ReportDoc>(
  {
    reporter: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    target: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    kind: { type: String, enum: ['report', 'block'], required: true },
    reason: { type: String, maxlength: 1000 },
    status: { type: String, enum: ['open', 'reviewing', 'resolved', 'dismissed'], default: 'open' },
    resolvedBy: { type: Schema.Types.ObjectId, ref: 'User', default: null },
    resolutionNote: { type: String, default: null },
  },
  { timestamps: true },
);

reportSchema.index({ reporter: 1, target: 1, kind: 1 });
reportSchema.index({ kind: 1, status: 1 });

export const Report = model<ReportDoc>('Report', reportSchema);
