import crypto from 'crypto';
import { UserDoc } from '../models/user.model';
import { Tier } from '../config/limits';
import { haversineMeters } from '../utils/geo';
import { env } from '../config/env';

/**
 * The shape every endpoint MUST use to describe another user's location.
 * Never hand-roll location output elsewhere — go through
 * `serializeUserLocation` so the free/premium privacy rules apply uniformly.
 */
export interface SerializedLocation {
  displayName: string | null;
  point: [number, number] | null; // [lng, lat]; fuzzed for free viewers, coarse-exact for premium
  distanceKm: number | null; // exact; premium-only, always null for free viewers
  distanceLabel: string | null; // bucketed range for free viewers; formatted exact km for premium
}

const NO_LOCATION: SerializedLocation = {
  displayName: null,
  point: null,
  distanceKm: null,
  distanceLabel: null,
};

const FUZZ_MAX_RADIUS_KM = 1.0;
const KM_PER_DEGREE_LAT = 111.32;

/** Deterministic pseudo-random value in [0, 1), keyed by seed+salt+index. */
function seededUnit(seed: string, index: number): number {
  const hash = crypto.createHmac('sha256', env.LOCATION_FUZZ_SALT).update(`${seed}:${index}`).digest();
  return hash.readUIntBE(0, 6) / 2 ** 48;
}

/**
 * Jitters a point within a `FUZZ_MAX_RADIUS_KM` disk. Deterministic per user
 * (same offset every call — the pin doesn't jump between requests/sessions),
 * salted so the offset can't be reproduced by anyone who only knows the id.
 */
function fuzzPoint(userId: string, [lng, lat]: [number, number]): [number, number] {
  const angle = seededUnit(userId, 0) * 2 * Math.PI;
  // sqrt() is required so the offset is uniform over the disk's AREA, not its radius.
  const distanceKm = FUZZ_MAX_RADIUS_KM * Math.sqrt(seededUnit(userId, 1));
  const dLat = (distanceKm / KM_PER_DEGREE_LAT) * Math.cos(angle);
  const kmPerDegreeLng = KM_PER_DEGREE_LAT * Math.cos((lat * Math.PI) / 180);
  const dLng = kmPerDegreeLng > 0 ? (distanceKm / kmPerDegreeLng) * Math.sin(angle) : 0;
  return [lng + dLng, lat + dLat];
}

function bucketDistanceLabel(km: number): string {
  if (km < 1) return '< 1 km';
  if (km < 3) return '1–3 km';
  if (km < 8) return '3–8 km';
  if (km < 20) return '8–20 km';
  return '20+ km';
}

/**
 * Serializes `target`'s location for `viewer`. Free viewers (the default)
 * get a fuzzed pin and a bucketed distance range — precise distance next to
 * a fuzzed pin would let someone triangulate the real location, so exact
 * numbers never accompany a fuzzed pin. Premium viewers get the stored
 * coarse pin un-jittered (still capped at ~1.1km precision — that cap is
 * never lifted) and an exact distance.
 */
export function serializeUserLocation(
  target: Pick<UserDoc, '_id' | 'location'>,
  viewer: { tier: Tier; location?: UserDoc['location'] },
): SerializedLocation {
  const targetPoint = target.location?.point?.coordinates;
  if (!targetPoint) return NO_LOCATION;

  const displayName = target.location?.displayName ?? null;
  const viewerPoint = viewer.location?.point?.coordinates;
  const realDistanceKm = viewerPoint ? haversineMeters(viewerPoint, targetPoint) / 1000 : null;

  if (viewer.tier === 'premium') {
    const rounded = realDistanceKm === null ? null : Math.round(realDistanceKm * 10) / 10;
    return {
      displayName,
      point: targetPoint,
      distanceKm: rounded,
      distanceLabel: rounded === null ? null : `${rounded} km`,
    };
  }

  return {
    displayName,
    point: fuzzPoint(String(target._id), targetPoint),
    distanceKm: null,
    distanceLabel: realDistanceKm === null ? null : bucketDistanceLabel(realDistanceKm),
  };
}
