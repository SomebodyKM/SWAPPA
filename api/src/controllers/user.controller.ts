import { RequestHandler } from 'express';
import { userService } from '../services/user.service';
import { locationService } from '../services/location.service';
import { serializeUserLocation } from '../services/locationPresenter';

export const userController: Record<string, RequestHandler> = {
  me: async (req, res) => {
    res.json(req.currentUser!.toJSON());
  },

  // Only ever the public-safe subset — unlike `me`, this is any authenticated
  // viewer looking at someone *else*, so email/phone/credits/role/etc never
  // belong in the response.
  getById: async (req, res) => {
    const user = await userService.getById(String(req.params.id));
    res.json({
      _id: user._id,
      displayName: user.displayName,
      photoUrl: user.photoUrl,
      bio: user.bio,
      tier: user.tier,
      ratingAvg: user.ratingAvg,
      ratingCount: user.ratingCount,
      // Never expose the raw location subdocument (exact-ish coarse point +
      // another user's placeId) — route it through the same presenter Discovery uses.
      location: serializeUserLocation(user, {
        tier: req.currentUser!.tier,
        location: req.currentUser!.location,
      }),
    });
  },

  updateMe: async (req, res) => {
    const user = await userService.updateProfile(req.auth!.userId, req.body);
    res.json(user.toJSON());
  },

  changeEmail: async (req, res) => {
    const user = await userService.changeEmail(req.auth!.userId, req.body.email);
    res.json(user.toJSON());
  },

  changePassword: async (req, res) => {
    await userService.changePassword(req.auth!.userId, req.body.currentPassword, req.body.newPassword);
    res.status(204).send();
  },

  addPushToken: async (req, res) => {
    await userService.addPushToken(req.auth!.userId, req.body.token);
    res.status(204).send();
  },

  deleteMe: async (req, res) => {
    await userService.deleteAccount(req.auth!.userId);
    res.status(204).send();
  },

  suggestLocation: async (req, res) => {
    const { query } = res.locals.query as { query: string };
    const items = await locationService.autocomplete(query);
    res.json({ items });
  },

  updateLocation: async (req, res) => {
    const body = req.body as { placeId?: string; lat?: number; lng?: number };
    const user = body.placeId
      ? await locationService.updateFromPlaceId(req.auth!.userId, body.placeId)
      : await locationService.updateFromDevice(req.auth!.userId, body.lat!, body.lng!);
    res.json(user.toJSON());
  },

  clearLocation: async (req, res) => {
    const user = await locationService.clear(req.auth!.userId);
    res.json(user.toJSON());
  },
};
