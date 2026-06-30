import { RequestHandler } from 'express';
import { userService } from '../services/user.service';

export const userController: Record<string, RequestHandler> = {
  me: async (req, res) => {
    res.json(req.currentUser!.toJSON());
  },

  getById: async (req, res) => {
    const user = await userService.getById(String(req.params.id));
    res.json(user.toJSON());
  },

  updateMe: async (req, res) => {
    const user = await userService.updateProfile(req.auth!.userId, req.body);
    res.json(user.toJSON());
  },

  addPushToken: async (req, res) => {
    await userService.addPushToken(req.auth!.userId, req.body.token);
    res.status(204).send();
  },

  deleteMe: async (req, res) => {
    await userService.deleteAccount(req.auth!.userId);
    res.status(204).send();
  },
};
