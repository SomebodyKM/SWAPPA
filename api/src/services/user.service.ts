import { User, UserDoc, LocationPrecision } from '../models/user.model';
import { isValidLngLat, makePoint } from '../utils/geo';
import { Errors } from '../utils/errors';

export interface UpdateProfileInput {
  displayName?: string;
  bio?: string;
  photoUrl?: string;
  location?: { lng: number; lat: number };
  locationPrecision?: LocationPrecision;
  consent?: boolean; // required to set precise location
}

export const userService = {
  async getById(id: string): Promise<UserDoc> {
    const user = await User.findById(id);
    if (!user) throw Errors.notFound('User not found');
    return user;
  },

  async updateProfile(userId: string, input: UpdateProfileInput): Promise<UserDoc> {
    const user = await User.findById(userId);
    if (!user) throw Errors.notFound('User not found');

    if (input.displayName !== undefined) user.displayName = input.displayName;
    if (input.bio !== undefined) user.bio = input.bio;
    if (input.photoUrl !== undefined) user.photoUrl = input.photoUrl;

    if (input.location) {
      const { lng, lat } = input.location;
      if (!isValidLngLat(lng, lat)) throw Errors.badRequest('Invalid coordinates');
      user.location = makePoint(lng, lat);
    }

    if (input.locationPrecision) {
      if (input.locationPrecision === 'precise' && !input.consent) {
        throw Errors.badRequest('Explicit consent is required to share precise location');
      }
      user.locationPrecision = input.locationPrecision;
    }

    await user.save();
    return user;
  },

  async addPushToken(userId: string, token: string): Promise<void> {
    await User.updateOne({ _id: userId }, { $addToSet: { pushTokens: token } });
  },

  async deleteAccount(userId: string): Promise<void> {
    // v1: hard delete. Retention/anonymization policy is a follow-up (analysis U2).
    await User.deleteOne({ _id: userId });
  },
};
