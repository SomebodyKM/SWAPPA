import { Types } from 'mongoose';
import { serializeUserLocation } from '../src/services/locationPresenter';
import { UserDoc } from '../src/models/user.model';

type TargetLike = Pick<UserDoc, '_id' | 'location'>;

function makeTarget(lng: number, lat: number, displayName = 'Camden, London'): TargetLike {
  return {
    _id: new Types.ObjectId(),
    location: {
      point: { type: 'Point', coordinates: [lng, lat] },
      displayName,
      placeId: 'abc123',
      precision: 'coarse',
    },
  } as TargetLike;
}

/** Moves `km` due north of `base` — close enough to haversine truth for test purposes. */
function pointNorthKm(base: [number, number], km: number): [number, number] {
  return [base[0], base[1] + km / 111.32];
}

function haversineKm(a: [number, number], b: [number, number]): number {
  const R = 6371;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b[1] - a[1]);
  const dLng = toRad(b[0] - a[0]);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(a[1])) * Math.cos(toRad(b[1])) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(h)));
}

const LONDON: [number, number] = [-0.14, 51.54];

describe('locationPresenter.serializeUserLocation', () => {
  it('returns all-null fields when the target has no location', () => {
    const target: TargetLike = { _id: new Types.ObjectId(), location: undefined };
    expect(serializeUserLocation(target, { tier: 'free' })).toEqual({
      displayName: null,
      point: null,
      distanceKm: null,
      distanceLabel: null,
    });
  });

  it('free viewers never get the real point, and the offset stays within the 1km disk', () => {
    const target = makeTarget(...LONDON);
    const out = serializeUserLocation(target, { tier: 'free' });
    expect(out.point).not.toEqual(LONDON);
    expect(haversineKm(LONDON, out.point!)).toBeLessThanOrEqual(1.0 + 1e-6);
    expect(out.distanceKm).toBeNull(); // exact distance never accompanies a fuzzed pin
  });

  it('the fuzzed offset is deterministic for the same user across calls', () => {
    const target = makeTarget(...LONDON);
    const a = serializeUserLocation(target, { tier: 'free' });
    const b = serializeUserLocation(target, { tier: 'free' });
    expect(a.point).toEqual(b.point);
  });

  it('different users at the same real location get different offsets', () => {
    const a = serializeUserLocation(makeTarget(...LONDON), { tier: 'free' });
    const b = serializeUserLocation(makeTarget(...LONDON), { tier: 'free' });
    expect(a.point).not.toEqual(b.point);
  });

  it.each([
    [0.5, '< 1 km'],
    [2, '1–3 km'],
    [5, '3–8 km'],
    [15, '8–20 km'],
    [30, '20+ km'],
  ])('buckets a %skm real distance as "%s" for free viewers', (km, label) => {
    const target = makeTarget(...pointNorthKm(LONDON, km));
    const out = serializeUserLocation(target, { tier: 'free', location: { point: { type: 'Point', coordinates: LONDON }, precision: 'coarse' } });
    expect(out.distanceLabel).toBe(label);
    expect(out.distanceKm).toBeNull();
  });

  it('free viewers with no location of their own get no distance label', () => {
    const target = makeTarget(...LONDON);
    const out = serializeUserLocation(target, { tier: 'free' });
    expect(out.distanceLabel).toBeNull();
  });

  it('premium viewers get the exact stored (coarse) point, un-jittered', () => {
    const target = makeTarget(...LONDON);
    const out = serializeUserLocation(target, { tier: 'premium' });
    expect(out.point).toEqual(LONDON);
  });

  it('premium viewers get an exact distance in km, not a bucket', () => {
    const target = makeTarget(...pointNorthKm(LONDON, 5));
    const out = serializeUserLocation(target, {
      tier: 'premium',
      location: { point: { type: 'Point', coordinates: LONDON }, precision: 'coarse' },
    });
    expect(out.distanceKm).not.toBeNull();
    expect(out.distanceKm!).toBeGreaterThan(4.5);
    expect(out.distanceKm!).toBeLessThan(5.5);
    expect(out.distanceLabel).toBe(`${out.distanceKm} km`);
  });

  it('premium viewers with no location of their own get no distance', () => {
    const target = makeTarget(...LONDON);
    const out = serializeUserLocation(target, { tier: 'premium' });
    expect(out.distanceKm).toBeNull();
    expect(out.distanceLabel).toBeNull();
  });
});
