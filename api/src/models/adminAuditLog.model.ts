import { Schema, model, Document, Types } from 'mongoose';

export type AdminAction =
  | 'skill_create'
  | 'skill_edit'
  | 'skill_delete'
  | 'user_ban'
  | 'user_unban'
  | 'user_suspend'
  | 'role_change'
  | 'report_resolve'
  | 'report_dismiss';

export type AdminTargetType = 'skill' | 'user' | 'report';

export interface AdminAuditLogDoc extends Document<Types.ObjectId> {
  _id: Types.ObjectId;
  admin: Types.ObjectId;
  action: AdminAction;
  targetType: AdminTargetType;
  targetId: Types.ObjectId;
  detail: Record<string, unknown>;
  createdAt: Date;
  updatedAt: Date;
}

const adminAuditLogSchema = new Schema<AdminAuditLogDoc>(
  {
    admin: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    action: { type: String, required: true },
    targetType: { type: String, enum: ['skill', 'user', 'report'], required: true },
    targetId: { type: Schema.Types.ObjectId, required: true },
    detail: { type: Schema.Types.Mixed, default: {} },
  },
  { timestamps: true },
);

adminAuditLogSchema.index({ admin: 1, createdAt: -1 });
adminAuditLogSchema.index({ targetType: 1, targetId: 1 });

export const AdminAuditLog = model<AdminAuditLogDoc>('AdminAuditLog', adminAuditLogSchema);
