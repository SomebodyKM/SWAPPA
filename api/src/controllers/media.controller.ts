import { RequestHandler } from 'express';
import { mediaService, MediaPurpose } from '../services/media.service';

export const mediaController: Record<string, RequestHandler> = {
  sign: async (req, res) => {
    const purpose = req.body.purpose as MediaPurpose;
    const signed = mediaService.signUpload(purpose, req.auth!.userId);
    res.json(signed);
  },
};
