import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateProvider is a legacy (but supported) provider in Riverpod 3.
import 'package:flutter_riverpod/legacy.dart';

import '../../core/providers.dart';
import 'match.dart';

/// Flip to `false` once auth + live data is wired to hit the real API.
/// While `true`, Discovery renders local sample data for design review.
const bool kUseSampleData = true;

/// Discovery filter: all | local | remote.
final discoveryModeProvider = StateProvider<String>((ref) => 'all');

/// List (false) vs Map (true) view.
final discoveryIsMapProvider = StateProvider<bool>((ref) => false);

/// Search query text.
final discoverySearchProvider = StateProvider<String>((ref) => '');

class DiscoveryResult {
  DiscoveryResult({required this.items, required this.capped});
  final List<MatchResult> items;
  final bool capped;
}

/// Loads matches for the current filter. Uses sample data when [kUseSampleData].
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
    return DiscoveryResult(items: filtered, capped: filtered.length > 2);
  }

  final api = ref.watch(apiClientProvider);
  final apiMode = mode == 'local' ? 'local' : 'remote';
  final res = await api.dio.get('/matches', queryParameters: {'mode': apiMode});
  final data = res.data as Map<String, dynamic>;
  final items = ((data['items'] as List?) ?? const [])
      .map((e) => MatchResult.fromJson(e as Map<String, dynamic>))
      .toList();
  return DiscoveryResult(items: items, capped: (data['capped'] ?? false) as bool);
});
