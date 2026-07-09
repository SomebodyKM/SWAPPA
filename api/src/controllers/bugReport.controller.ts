import { RequestHandler } from 'express';
import { bugReportService } from '../services/bugReport.service';

export const bugReportController: Record<string, RequestHandler> = {
  submit: async (req, res) => {
    res.status(201).json(await bugReportService.submit(req.auth!.userId, req.body.description));
  },

  listMine: async (req, res) => {
    res.json({ items: await bugReportService.listMine(req.auth!.userId) });
  },
};
