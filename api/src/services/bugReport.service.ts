import { BugReport, BugReportDoc } from '../models/bugReport.model';
import { User } from '../models/user.model';
import { notificationService } from './notification.service';

export const bugReportService = {
  /** Any signed-in user can file one — every admin is notified in real time,
   * mirroring how a proposed skill notifies admins (see skillService.proposeSkill). */
  async submit(reporterId: string, description: string): Promise<BugReportDoc> {
    const bugReport = await BugReport.create({ reporter: reporterId, description });

    const admins = await User.find({ role: 'admin', status: 'active' }).select('_id');
    await Promise.all(
      admins.map((admin) =>
        notificationService.notify({
          userId: String(admin._id),
          type: 'bug_submitted',
          title: 'New bug report',
          body: description,
          data: { bugReportId: String(bugReport._id) },
        }),
      ),
    );
    return bugReport;
  },

  async listMine(reporterId: string): Promise<BugReportDoc[]> {
    return BugReport.find({ reporter: reporterId }).sort({ createdAt: -1 });
  },
};
