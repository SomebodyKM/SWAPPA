import { User, UserDoc } from '../models/user.model';
import { env } from '../config/env';
import { Errors } from '../utils/errors';
import { isValidLngLat, roundCoord } from '../utils/geo';

/** Place types considered "region-level" — safe to store as a profile location. */
const REGION_TYPES = new Set([
  'locality',
  'sublocality',
  'sublocality_level_1',
  'sublocality_level_2',
  'neighborhood',
  'postal_code',
  'postal_town',
  'administrative_area_level_1',
  'administrative_area_level_2',
  'administrative_area_level_3',
  'country',
]);

/** Street-level types we reject even if a region type is also present. */
const STREET_LEVEL_TYPES = new Set(['street_address', 'premise', 'subpremise', 'route']);

/**
 * Places API (New) caps `includedPrimaryTypes` at 5 values, so this is a
 * best-effort narrowing at autocomplete time only — the full `REGION_TYPES`/
 * `STREET_LEVEL_TYPES` check in `updateFromPlaceId` is the real gate.
 */
const AUTOCOMPLETE_PRIMARY_TYPES = [
  'locality',
  'sublocality',
  'neighborhood',
  'administrative_area_level_1',
  'postal_code',
];

function apiKey(): string {
  if (!env.GOOGLE_MAPS_SERVER_KEY) throw Errors.internal('Location search is not configured');
  return env.GOOGLE_MAPS_SERVER_KEY;
}

export interface LocationSuggestion {
  placeId: string;
  description: string;
}

interface PlacesAutocompleteResponse {
  suggestions?: { placePrediction?: { placeId: string; text?: { text: string } } }[];
  error?: { message?: string };
}

interface PlaceDetailsResponse {
  types?: string[];
  formattedAddress?: string;
  location?: { latitude: number; longitude: number };
  displayName?: { text?: string };
  error?: { message?: string };
}

interface GoogleGeocodeResponse {
  status: string;
  results?: { formatted_address?: string; place_id?: string }[];
}

export const locationService = {
  /**
   * Region-level place suggestions for the manual location picker. Proxied
   * server-side so no Google key ever ships in the Flutter bundle. Uses
   * Places API (New) — the legacy Places API returns REQUEST_DENIED unless
   * a project has specifically re-enabled it, which new projects don't.
   */
  async autocomplete(query: string): Promise<LocationSuggestion[]> {
    const res = await fetch('https://places.googleapis.com/v1/places:autocomplete', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Goog-Api-Key': apiKey() },
      body: JSON.stringify({ input: query, includedPrimaryTypes: AUTOCOMPLETE_PRIMARY_TYPES }),
    });
    const data = (await res.json()) as PlacesAutocompleteResponse;
    if (!res.ok) throw Errors.internal(data.error?.message ?? 'Location search failed');

    return (data.suggestions ?? [])
      .map((s) => s.placePrediction)
      .filter((p): p is { placeId: string; text?: { text: string } } => !!p)
      .map((p) => ({ placeId: p.placeId, description: p.text?.text ?? '' }));
  },

  /**
   * Resolves a place_id (chosen from autocomplete) to a rounded, region-level
   * point and stores it. Rejects street-level places even though the client
   * already narrows autocomplete to region types — defense in depth, and the
   * real gate here since autocomplete's type filter is capped at 5 values.
   */
  async updateFromPlaceId(userId: string, placeId: string): Promise<UserDoc> {
    const res = await fetch(`https://places.googleapis.com/v1/places/${placeId}`, {
      headers: {
        'X-Goog-Api-Key': apiKey(),
        'X-Goog-FieldMask': 'displayName,formattedAddress,location,types',
      },
    });
    const data = (await res.json()) as PlaceDetailsResponse;
    if (!res.ok || !data.location) {
      throw Errors.badRequest('Could not resolve that place');
    }

    const types = data.types ?? [];
    const isRegion = types.some((t) => REGION_TYPES.has(t));
    const isStreetLevel = types.some((t) => STREET_LEVEL_TYPES.has(t));
    if (!isRegion || isStreetLevel) {
      throw Errors.badRequest('Please choose a city or area, not a street address');
    }

    return this.store(userId, {
      lng: roundCoord(data.location.longitude),
      lat: roundCoord(data.location.latitude),
      placeId,
      displayName: data.displayName?.text ?? data.formattedAddress ?? 'Unknown area',
    });
  },

  /**
   * Stores a coarse device fix. The client only ever requests reduced-accuracy
   * location, but we re-round and reverse-geocode here regardless — never
   * trust client-reported precision.
   */
  async updateFromDevice(userId: string, lat: number, lng: number): Promise<UserDoc> {
    if (!isValidLngLat(lng, lat)) throw Errors.badRequest('Invalid coordinates');
    const roundedLat = roundCoord(lat);
    const roundedLng = roundCoord(lng);

    const url = new URL('https://maps.googleapis.com/maps/api/geocode/json');
    url.searchParams.set('latlng', `${roundedLat},${roundedLng}`);
    url.searchParams.set('result_type', 'locality|sublocality|neighborhood');
    url.searchParams.set('key', apiKey());

    const res = await fetch(url);
    const data = (await res.json()) as GoogleGeocodeResponse;
    const top = data.status === 'OK' ? data.results?.[0] : undefined;

    return this.store(userId, {
      lng: roundedLng,
      lat: roundedLat,
      placeId: top?.place_id,
      displayName: top?.formatted_address ?? 'Approximate area',
    });
  },

  async store(
    userId: string,
    input: { lng: number; lat: number; placeId?: string; displayName: string },
  ): Promise<UserDoc> {
    const user = await User.findById(userId);
    if (!user) throw Errors.notFound('User not found');
    user.location = {
      point: { type: 'Point', coordinates: [input.lng, input.lat] },
      placeId: input.placeId,
      displayName: input.displayName,
      precision: 'coarse',
      updatedAt: new Date(),
    };
    await user.save();
    return user;
  },

  /** Clears a stored location — the user goes back to "not set" (shows as Remote). */
  async clear(userId: string): Promise<UserDoc> {
    const user = await User.findById(userId);
    if (!user) throw Errors.notFound('User not found');
    user.location = undefined;
    await user.save();
    return user;
  },
};
