import { RequestHandler } from 'express';
import { skillService } from '../services/skill.service';

export const skillController: Record<string, RequestHandler> = {
  // Catalog
  browse: async (_req, res) => {
    const q = (res.locals.query ?? {}) as { query?: string; all?: boolean };
    const skills = await skillService.search(q.query, q.all === true);
    res.json({ items: skills });
  },

  categories: async (_req, res) => {
    res.json({ items: await skillService.categories() });
  },

  read: async (req, res) => {
    res.json(await skillService.getById(String(req.params.id)));
  },

  create: async (req, res) => {
    const skill = await skillService.proposeSkill(req.body.name, req.body.category);
    res.status(201).json(skill);
  },

  // Skill tags
  listMyTags: async (req, res) => {
    res.json({ items: await skillService.listTags(req.auth!.userId) });
  },

  listUserTags: async (req, res) => {
    res.json({ items: await skillService.listTags(String(req.params.id)) });
  },

  addTag: async (req, res) => {
    const tag = await skillService.addTag(req.auth!.userId, req.body);
    res.status(201).json(tag);
  },

  updateTag: async (req, res) => {
    const tag = await skillService.updateTag(
      req.auth!.userId,
      String(req.params.tagId),
      req.body.proficiency,
    );
    res.json(tag);
  },

  removeTag: async (req, res) => {
    await skillService.removeTag(req.auth!.userId, String(req.params.tagId));
    res.status(204).send();
  },
};
