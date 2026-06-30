import { v2 as cloudinary } from 'cloudinary';
import { env } from '../config/env';
import { Errors } from '../utils/errors';

let configured = false;

function ensureConfigured(): void {
  if (configured) return;
  if (!env.CLOUDINARY_CLOUD_NAME || !env.CLOUDINARY_API_KEY || !env.CLOUDINARY_API_SECRET) {
    throw Errors.internal('Cloudinary is not configured');
  }
  cloudinary.config({
    cloud_name: env.CLOUDINARY_CLOUD_NAME,
    api_key: env.CLOUDINARY_API_KEY,
    api_secret: env.CLOUDINARY_API_SECRET,
  });
  configured = true;
}

export type MediaPurpose = 'avatar' | 'message';

export interface SignedUpload {
  timestamp: number;
  signature: string;
  apiKey: string;
  cloudName: string;
  folder: string;
}

export const mediaService = {
  /** Issues signed params so the client can upload directly to Cloudinary. */
  signUpload(purpose: MediaPurpose, userId: string): SignedUpload {
    ensureConfigured();
    const timestamp = Math.round(Date.now() / 1000);
    const folder = `swappa/${purpose}/${userId}`;
    const signature = cloudinary.utils.api_sign_request(
      { timestamp, folder },
      env.CLOUDINARY_API_SECRET as string,
    );
    return {
      timestamp,
      signature,
      apiKey: env.CLOUDINARY_API_KEY as string,
      cloudName: env.CLOUDINARY_CLOUD_NAME as string,
      folder,
    };
  },
};
