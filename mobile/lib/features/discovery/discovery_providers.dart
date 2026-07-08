import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateProvider is a legacy (but supported) provider in Riverpod 3.
import 'package:flutter_riverpod/legacy.dart';

import '../../core/providers.dart';
import 'match.dart';

/// Flip to `true` to render local sample data for design review instead of
/// hitting the real API.
const bool kUseSampleData = false;

/// Discovery filter: all | local | remote.
/// - all: everyone who shares a skill, regardless of location.
/// - local: has a location set, within the viewer's tier radius.
/// - remote: has NOT set a location at all (opted out — shows as "Remote").
final discoveryModeProvider = StateProvider<String>((ref) => 'all');

/// List (false) vs Map (true) view.
final discoveryIsMapProvider = StateProvider<bool>((ref) => false);

/// Search query text.
final discoverySearchProvider = StateProvider<String>((ref) => '');

class DiscoveryResult {
  DiscoveryResult({
    required this.items,
    required this.capped,
    this.hiddenCount = 0,
    this.teasers = const [],
  });

  /// The actually-visible, renderable matches.
  final List<MatchResult> items;
  final bool capped;

  /// True count of matches withheld behind the free-tier cap (from the
  /// backend's `totalCount`, not just `items.length` — the API deliberately
  /// never sends the hidden candidates' identities, only how many there are).
  final int hiddenCount;

  /// Non-identifying previews (skill + distance only) of a handful of the
  /// hidden matches, straight from the backend's `teasers` — lets free users
  /// see there's real, relevant people just past the cap, without exposing
  /// who they are.
  final List<MatchTeaser> teasers;
}

/// Loads matches for the current mode. Uses sample data when [kUseSampleData].
/// Not keyed to the search box on purpose — search narrows the already-loaded
/// list client-side (see [filteredMatchesProvider]) rather than refetching on
/// every keystroke.
final matchesProvider = FutureProvider<DiscoveryResult>((ref) async {
  final mode = ref.watch(discoveryModeProvider);

  if (kUseSampleData) {
    final all = sampleMatches();
    final filtered = switch (mode) {
      'local' => all.where((m) => !m.isRemote).toList(),
      'remote' => all.where((m) => m.isRemote).toList(),
      _ => all,
    };
    // Free tier shows top 2 with a soft paywall for the rest.
    final capped = filtered.length > 2;
    final visible = capped ? filtered.take(2).toList() : filtered;
    final hidden = capped ? filtered.skip(2).toList() : const <MatchResult>[];
    return DiscoveryResult(
      items: visible,
      capped: capped,
      hiddenCount: hidden.length,
      teasers: hidden
          .take(5)
          .map(
            (m) => MatchTeaser(
              teachesName: m.teaches,
              wantsName: m.wants,
              distanceLabel: m.location.distanceLabel,
              mutual: m.mutual,
            ),
          )
          .toList(),
    );
  }

  final api = ref.watch(apiClientProvider);
  // 'all' and 'remote' both mean "don't apply a radius filter" server-side —
  // the backend only distinguishes local (distance-filtered) from everything
  // else. The 'remote' UI tab additionally narrows to candidates with no
  // location set at all, applied client-side below.
  final apiMode = mode == 'local' ? 'local' : 'remote';
  final res = await api.dio.get('/matches', queryParameters: {'mode': apiMode});
  final data = res.data as Map<String, dynamic>;
  var items = ((data['items'] as List?) ?? const [])
      .map((e) => MatchResult.fromJson(e as Map<String, dynamic>))
      .toList();
  final capped = (data['premiumUnlocksFullList'] ?? false) as bool;
  final totalCount = (data['totalCount'] as num?)?.toInt() ?? items.length;
  final hiddenCount = capped
      ? (totalCount - items.length).clamp(0, totalCount)
      : 0;
  final teasers = ((data['teasers'] as List?) ?? const [])
      .map((e) => MatchTeaser.fromJson(e as Map<String, dynamic>))
      .toList();

  if (mode == 'remote') {
    items = items.where((m) => m.isRemote).toList();
  }

  return DiscoveryResult(
    items: items,
    capped: capped,
    hiddenCount: hiddenCount,
    teasers: teasers,
  );
});

/// [matchesProvider], narrowed by the search box against each match's
/// resolved skill name — client-side so typing doesn't refetch from the network.
final filteredMatchesProvider = Provider<AsyncValue<DiscoveryResult>>((ref) {
  final query = ref.watch(discoverySearchProvider).trim().toLowerCase();
  final async = ref.watch(matchesProvider);
  if (query.isEmpty) return async;
  return async.whenData((result) {
    final items = result.items
        .where((m) => (m.teaches ?? '').toLowerCase().contains(query))
        .toList();
    return DiscoveryResult(items: items, capped: false, hiddenCount: 0);
  });
});
