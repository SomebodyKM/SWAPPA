import { RequestHandler } from 'express';
import { adminService } from '../services/admin.service';
import { ReportStatus } from '../models/report.model';

export const adminController: Record<string, RequestHandler> = {
  // Skills
  createSkill: async (req, res) => {
    res.status(201).json(await adminService.createSkill(req.auth!.userId, req.body.name, req.body.category));
  },
  updateSkill: async (req, res) => {
    res.json(await adminService.updateSkill(req.auth!.userId, String(req.params.id), req.body));
  },
  deleteSkill: async (req, res) => {
    await adminService.deleteSkill(req.auth!.userId, String(req.params.id));
    res.status(204).send();
  },
  pendingSkills: async (_req, res) => {
    res.json({ items: await adminService.listPendingSkills() });
  },

  // Users
  listUsers: async (req, res) => {
    const q = (res.locals.query ?? {}) as { query?: string };
    res.json({ items: await adminService.listUsers(q.query) });
  },
  banUser: async (req, res) => {
    await adminService.banUser(req.auth!.userId, String(req.params.id), req.body.reason);
    res.json({ status: 'ok' });
  },
  suspendUser: async (req, res) => {
    await adminService.suspendUser(req.auth!.userId, String(req.params.id), req.body.reason);
    res.json({ status: 'ok' });
  },
  unbanUser: async (req, res) => {
    await adminService.unbanUser(req.auth!.userId, String(req.params.id));
    res.json({ status: 'ok' });
  },
  setRole: async (req, res) => {
    await adminService.setRole(req.auth!.userId, String(req.params.id), req.body.role);
    res.json({ status: 'ok' });
  },

  // Reports
  listReports: async (req, res) => {
    const q = (res.locals.query ?? {}) as { status?: ReportStatus };
    res.json({ items: await adminService.listReports(q.status) });
  },
  resolveReport: async (req, res) => {
    res.json(await adminService.resolveReport(req.auth!.userId, String(req.params.id), req.body.note ?? ''));
  },
  dismissReport: async (req, res) => {
    res.json(await adminService.dismissReport(req.auth!.userId, String(req.params.id), req.body.note ?? ''));
  },

  // Audit + metrics
  auditLog: async (_req, res) => {
    res.json({ items: await adminService.auditLog() });
  },
  metrics: async (_req, res) => {
    res.json(await adminService.metrics());
  },
};
