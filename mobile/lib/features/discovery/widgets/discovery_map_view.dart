import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../design_system/tokens.dart';
import '../../ai/ai_sheet.dart';
import '../../auth/auth_controller.dart';
import '../../chat/chat_thread.dart';
import '../discovery_providers.dart';
import '../match.dart';
import 'map_pins.dart';
import 'match_card.dart';

/// Discovery's map view. Pins come straight from [MatchResult.location] —
/// already fuzzed or exact per the backend's free/premium presentation rules
/// (`locationPresenter.ts`); this widget never re-derives or adjusts precision.
///
/// Built on `flutter_map` (free, no account/token) rather than the location
/// spec's suggested Mapbox — product direction is to start here and swap to
/// Google Maps in a later update. Everything except this file's `FlutterMap`/
/// `TileLayer` widgets (data wiring, clustering, the free-tier footer, the
/// viewer's own marker) carries over unchanged when that swap happens.
class DiscoveryMapView extends ConsumerStatefulWidget {
  const DiscoveryMapView({super.key});

  @override
  ConsumerState<DiscoveryMapView> createState() => _DiscoveryMapViewState();
}

class _DiscoveryMapViewState extends ConsumerState<DiscoveryMapView> {
  MatchResult? _selected;

  void _togglePin(MatchResult match) {
    setState(
      () => _selected = _selected?.candidateId == match.candidateId
          ? null
          : match,
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(filteredMatchesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const _MapMessage(
        icon: Icons.error_outline_rounded,
        title: 'Couldn’t load the map',
      ),
      data: (result) {
        final me = ref.watch(authControllerProvider).user;
        final myPoint = me?.location.point;
        final pins = result.items
            .where((m) => m.location.point != null)
            .toList();

        if (myPoint == null && pins.isEmpty) {
          return const _MapMessage(
            icon: Icons.map_outlined,
            title: 'No locations to show yet',
            subtitle:
                'Set your location in Settings to see nearby matches on the map.',
          );
        }

        final center = myPoint != null
            ? LatLng(myPoint[1], myPoint[0])
            : LatLng(
                pins.first.location.point![1],
                pins.first.location.point![0],
              );

        return Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 11,
                onTap: (_, _) => setState(() => _selected = null),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.swappa.swappa',
                ),
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 45,
                    computeSize: (markers) {
                      final d = ClusterMapPin.diameterFor(markers.length);
                      return Size(d, d);
                    },
                    markers: [
                      for (final m in pins)
                        Marker(
                          point: LatLng(
                            m.location.point![1],
                            m.location.point![0],
                          ),
                          width: MatchMapPin.widthFor(m.mutual),
                          height: MatchMapPin.heightFor(m.mutual),
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            onTap: () => _togglePin(m),
                            child: MatchMapPin(match: m),
                          ),
                        ),
                    ],
                    builder: (context, markers) =>
                        ClusterMapPin(count: markers.length),
                  ),
                ),
                if (myPoint != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(myPoint[1], myPoint[0]),
                        width: SelfMapPin.size,
                        height: SelfMapPin.size,
                        child: const SelfMapPin(),
                      ),
                    ],
                  ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
            if (_selected != null)
              Positioned(
                left: Insets.md,
                right: Insets.md,
                bottom: Insets.md,
                child: _FloatingMatchCard(
                  match: _selected!,
                  onClose: () => setState(() => _selected = null),
                ),
              )
            else if (!(me?.isPremium ?? false))
              const Positioned(
                left: Insets.md,
                right: Insets.md,
                bottom: Insets.md,
                child: Center(child: _ApproximateFooter()),
              ),
          ],
        );
      },
    );
  }
}

/// The tapped candidate's [MatchCard], floating over the map (no dimming
/// backdrop) so the map stays visible/pannable underneath. Dismissed by the
/// close button, tapping the same pin again, or tapping elsewhere on the map.
class _FloatingMatchCard extends ConsumerWidget {
  const _FloatingMatchCard({required this.match, required this.onClose});
  final MatchResult match;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.md),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: MatchCard(
            match: match,
            onMessage: () => openChatWith(context, ref, match.candidateId),
            onIcebreaker: () async {
              final text = await showAiSheet(
                context,
                'icebreaker',
                matchUserId: match.candidateId,
              );
              if (text != null && context.mounted) {
                await openChatWith(
                  context,
                  ref,
                  match.candidateId,
                  initialDraft: text,
                );
              }
            },
          ),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: GestureDetector(
            onTap: onClose,
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.outlineVariant),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4),
                ],
              ),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: scheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ApproximateFooter extends StatelessWidget {
  const _ApproximateFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline_rounded, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            'Locations shown are approximate',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapMessage extends StatelessWidget {
  const _MapMessage({required this.icon, required this.title, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: scheme.onSurfaceVariant),
            const SizedBox(height: Insets.md),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
