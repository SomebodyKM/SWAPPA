import { Types } from 'mongoose';
import { Report, ReportDoc } from '../models/report.model';
import { User } from '../models/user.model';
import { notificationService } from './notification.service';
import { Errors } from '../utils/errors';

export const safetyService = {
  async report(reporterId: string, targetUserId: string, reason: string): Promise<ReportDoc> {
    if (reporterId === targetUserId) throw Errors.badRequest('You cannot report yourself');
    const target = await User.exists({ _id: targetUserId });
    if (!target) throw Errors.notFound('User not found');
    const report = await Report.create({ reporter: reporterId, target: targetUserId, kind: 'report', reason });

    const admins = await User.find({ role: 'admin', status: 'active' }).select('_id');
    await Promise.all(
      admins.map((admin) =>
        notificationService.notify({
          userId: String(admin._id),
          type: 'report_submitted',
          title: 'New report',
          body: reason ? `Reason: ${reason}` : 'A user was reported',
          data: { reportId: String(report._id) },
        }),
      ),
    );
    return report;
  },

  async block(reporterId: string, targetUserId: string): Promise<ReportDoc> {
    if (reporterId === targetUserId) throw Errors.badRequest('You cannot block yourself');
    const existing = await Report.findOne({ reporter: reporterId, target: targetUserId, kind: 'block' });
    if (existing) return existing;
    return Report.create({ reporter: reporterId, target: targetUserId, kind: 'block' });
  },

  async unblock(reporterId: string, targetUserId: string): Promise<void> {
    await Report.deleteOne({ reporter: reporterId, target: targetUserId, kind: 'block' });
  },

  async listBlocks(userId: string): Promise<ReportDoc[]> {
    return Report.find({ reporter: userId, kind: 'block' }).populate('target', 'displayName photoUrl');
  },

  /** Reports the given user has filed against others — their own report history. */
  async listMyReports(userId: string): Promise<ReportDoc[]> {
    return Report.find({ reporter: userId, kind: 'report' })
      .sort({ createdAt: -1 })
      .populate('target', 'displayName photoUrl');
  },

  /** All user ids the given user has blocked OR been blocked by (for discovery/messaging exclusion). */
  async blockedUserIds(userId: string): Promise<Types.ObjectId[]> {
    const oid = new Types.ObjectId(userId);
    const blocks = await Report.find({
      kind: 'block',
      $or: [{ reporter: oid }, { target: oid }],
    }).select('reporter target');
    const ids = new Set<string>();
    for (const b of blocks) {
      ids.add(String(b.reporter) === userId ? String(b.target) : String(b.reporter));
    }
    return [...ids].map((id) => new Types.ObjectId(id));
  },
};
