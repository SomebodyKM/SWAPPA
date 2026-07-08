import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/providers.dart';

/// A region-level place suggestion from the manual location picker.
/// Deliberately carries only [placeId] + [description] — the client never
/// resolves or sends coordinates itself for manual entry; the backend
/// resolves the place_id server-side (see `location.service.ts`).
class LocationSuggestion {
  const LocationSuggestion({required this.placeId, required this.description});
  final String placeId;
  final String description;

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) =>
      LocationSuggestion(
        placeId: (json['placeId'] ?? '').toString(),
        description: (json['description'] ?? '') as String,
      );
}

class LocationRepository {
  LocationRepository(this._api);
  final ApiClient _api;

  Future<List<LocationSuggestion>> suggest(String query) async {
    final data = await _api.getJson(
      '/users/me/location/suggest',
      query: {'query': query},
    );
    final items = (data is Map ? data['items'] : null) as List? ?? const [];
    return items
        .map((e) => LocationSuggestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Resolves [placeId] server-side and stores the rounded, region-level
  /// point. Returns the resolved display name for immediate confirmation.
  Future<String?> updateFromPlaceId(String placeId) async {
    final data = await _api.patchJson(
      '/users/me/location',
      body: {'placeId': placeId},
    );
    final location =
        (data is Map ? data['location'] : null) as Map<String, dynamic>?;
    return location?['displayName'] as String?;
  }

  /// Sends a coarse device fix; the backend re-rounds and reverse-geocodes
  /// regardless of what's sent (never trusts client-reported precision).
  Future<String?> updateFromDevice({
    required double lat,
    required double lng,
  }) async {
    final data = await _api.patchJson(
      '/users/me/location',
      body: {'lat': lat, 'lng': lng, 'source': 'device'},
    );
    final location =
        (data is Map ? data['location'] : null) as Map<String, dynamic>?;
    return location?['displayName'] as String?;
  }

  /// Clears the stored location — back to "not set" (shows as Remote to others).
  Future<void> clear() => _api.deleteJson('/users/me/location');
}

final locationRepositoryProvider = Provider<LocationRepository>(
  (ref) => LocationRepository(ref.watch(apiClientProvider)),
);
