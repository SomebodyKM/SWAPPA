import { Types } from 'mongoose';
import { Skill, SkillDoc, normalizeSkillName } from '../models/skill.model';
import { User } from '../models/user.model';
import { Report, ReportDoc, ReportStatus } from '../models/report.model';
import { Swap } from '../models/swap.model';
import { Session } from '../models/session.model';
import { CreditTransaction } from '../models/creditTransaction.model';
import { AdminAuditLog, AdminAction, AdminTargetType } from '../models/adminAuditLog.model';
import { notificationService } from './notification.service';
import { Errors } from '../utils/errors';

async function audit(
  adminId: string,
  action: AdminAction,
  targetType: AdminTargetType,
  targetId: Types.ObjectId | string,
  detail: Record<string, unknown> = {},
): Promise<void> {
  await AdminAuditLog.create({ admin: adminId, action, targetType, targetId, detail });
}

export const adminService = {
  // ---- Skill catalog ----
  async createSkill(adminId: string, name: string, category: string): Promise<SkillDoc> {
    const nameNormalized = normalizeSkillName(name);
    const existing = await Skill.findOne({ nameNormalized });
    if (existing) {
      if (existing.status !== 'approved') {
        existing.status = 'approved';
        await existing.save();
      }
      return existing;
    }
    const skill = await Skill.create({ name: name.trim(), nameNormalized, category, status: 'approved' });
    await audit(adminId, 'skill_create', 'skill', skill._id, { name, category });
    return skill;
  },

  async updateSkill(
    adminId: string,
    skillId: string,
    input: { name?: string; category?: string; aliases?: string[]; status?: 'approved' | 'pending' },
  ): Promise<SkillDoc> {
    const skill = await Skill.findById(skillId);
    if (!skill) throw Errors.notFound('Skill not found');
    if (input.name) {
      skill.name = input.name.trim();
      skill.nameNormalized = normalizeSkillName(input.name);
    }
    if (input.category) skill.category = input.category;
    if (input.aliases) skill.aliases = input.aliases;
    if (input.status) skill.status = input.status;
    await skill.save();
    await audit(adminId, 'skill_edit', 'skill', skill._id, input);
    return skill;
  },

  async deleteSkill(adminId: string, skillId: string): Promise<void> {
    const res = await Skill.deleteOne({ _id: skillId });
    if (res.deletedCount === 0) throw Errors.notFound('Skill not found');
    await audit(adminId, 'skill_delete', 'skill', skillId);
  },

  async listPendingSkills(): Promise<SkillDoc[]> {
    return Skill.find({ status: 'pending' }).sort({ createdAt: -1 });
  },

  // ---- User moderation ----
  async banUser(adminId: string, userId: string, reason: string): Promise<void> {
    const user = await User.findById(userId);
    if (!user) throw Errors.notFound('User not found');
    user.status = 'banned';
    user.banReason = reason;
    user.bannedAt = new Date();
    user.bannedBy = new Types.ObjectId(adminId);
    await user.save();
    await this.releaseActiveEngagements(userId);
    await audit(adminId, 'user_ban', 'user', userId, { reason });
    await notificationService.notify({
      userId,
      type: 'moderation_action',
      title: 'Account banned',
      body: reason || 'Your account has been banned',
      data: { action: 'ban', reason },
    });
  },

  async suspendUser(adminId: string, userId: string, reason: string): Promise<void> {
    const user = await User.findById(userId);
    if (!user) throw Errors.notFound('User not found');
    user.status = 'suspended';
    user.banReason = reason;
    user.bannedAt = new Date();
    user.bannedBy = new Types.ObjectId(adminId);
    await user.save();
    await audit(adminId, 'user_suspend', 'user', userId, { reason });
    await notificationService.notify({
      userId,
      type: 'moderation_action',
      title: 'Account suspended',
      body: reason || 'Your account has been suspended',
      data: { action: 'suspend', reason },
    });
  },

  async unbanUser(adminId: string, userId: string): Promise<void> {
    const user = await User.findById(userId);
    if (!user) throw Errors.notFound('User not found');
    user.status = 'active';
    user.banReason = null;
    user.bannedAt = null;
    user.bannedBy = null;
    await user.save();
    await audit(adminId, 'user_unban', 'user', userId);
  },

  async setRole(adminId: string, userId: string, role: 'user' | 'admin'): Promise<void> {
    const user = await User.findById(userId);
    if (!user) throw Errors.notFound('User not found');
    user.role = role;
    await user.save();
    await audit(adminId, 'role_change', 'user', userId, { role });
  },

  /** Cancel a banned user's in-flight swaps/sessions so partners aren't stuck. */
  async releaseActiveEngagements(userId: string): Promise<void> {
    await Swap.updateMany(
      { participants: userId, status: { $in: ['requested', 'active'] } },
      { status: 'cancelled' },
    );
    await Session.updateMany(
      { $or: [{ teacher: userId }, { learner: userId }], status: { $in: ['proposed', 'accepted'] } },
      { status: 'cancelled' },
    );
  },

  async listUsers(query: string | undefined, limit = 50): Promise<unknown[]> {
    const filter: Record<string, unknown> = {};
    if (query) filter.$or = [{ email: new RegExp(query, 'i') }, { displayName: new RegExp(query, 'i') }];
    return User.find(filter).select('displayName email status role ratingAvg createdAt').limit(limit);
  },

  // ---- Reports ----
  async listReports(status?: ReportStatus): Promise<ReportDoc[]> {
    const filter: Record<string, unknown> = { kind: 'report' };
    if (status) filter.status = status;
    return Report.find(filter)
      .sort({ createdAt: -1 })
      .populate('reporter target', 'displayName email');
  },

  async resolveReport(adminId: string, reportId: string, note: string): Promise<ReportDoc> {
    const report = await Report.findById(reportId);
    if (!report || report.kind !== 'report') throw Errors.notFound('Report not found');
    report.status = 'resolved';
    report.resolvedBy = new Types.ObjectId(adminId);
    report.resolutionNote = note;
    await report.save();
    await audit(adminId, 'report_resolve', 'report', report._id, { note });
    return report;
  },

  async dismissReport(adminId: string, reportId: string, note: string): Promise<ReportDoc> {
    const report = await Report.findById(reportId);
    if (!report || report.kind !== 'report') throw Errors.notFound('Report not found');
    report.status = 'dismissed';
    report.resolvedBy = new Types.ObjectId(adminId);
    report.resolutionNote = note;
    await report.save();
    await audit(adminId, 'report_dismiss', 'report', report._id, { note });
    return report;
  },

  async auditLog(limit = 100): Promise<unknown[]> {
    return AdminAuditLog.find().sort({ createdAt: -1 }).limit(limit).populate('admin', 'displayName');
  },

  // ---- Metrics ----
  async metrics(): Promise<Record<string, number>> {
    const [users, activeSwaps, completedSwaps, premium, aiSpends, boostPurchases] = await Promise.all([
      User.countDocuments({}),
      Swap.countDocuments({ status: { $in: ['requested', 'active'] } }),
      Swap.countDocuments({ status: 'completed' }),
      User.countDocuments({ tier: 'premium' }),
      CreditTransaction.countDocuments({ type: 'spend' }),
      CreditTransaction.countDocuments({ type: 'purchase' }),
    ]);
    return { users, activeSwaps, completedSwaps, premium, aiSpends, boostPurchases };
  },
};
