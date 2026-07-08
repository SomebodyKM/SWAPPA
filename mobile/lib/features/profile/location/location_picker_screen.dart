import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/api_client.dart';
import '../../../design_system/app_colors.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/sub_page.dart';
import '../../auth/auth_controller.dart';
import 'location_repository.dart';

/// Manual location entry: search a city/area (backend-proxied Google Places
/// Autocomplete — no Google key ever ships to this app), pick a suggestion,
/// and the backend resolves + rounds it server-side.
class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<LocationSuggestion> _suggestions = const [];
  bool _searching = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _search(trimmed),
    );
  }

  Future<void> _search(String value) async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await ref.read(locationRepositoryProvider).suggest(value);
      if (mounted) setState(() => _suggestions = results);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  /// Requests coarse-only location (never FINE — see the Android manifest /
  /// iOS Info.plist entries) and sends the fix to the backend, which
  /// re-rounds and reverse-geocodes it regardless of what we send. Denied
  /// permission or disabled services fall back gracefully to manual search
  /// — this never blocks using the app.
  Future<void> _useCurrentLocation() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(
          () => _error =
              'Location services are turned off. Enable them, or search for your area above.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(
          () => _error =
              "Location permission was denied — you can still search for your area above.",
        );
        return;
      }

      // A time limit is essential here: without one, a device/emulator with
      // no GPS fix available (very common on emulators with no mock location
      // set) leaves the plugin's native location service waiting forever,
      // which the OS eventually kills as an ANR instead of this throwing a
      // catchable error.
      const timeLimit = Duration(seconds: 10);
      final settings = defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: timeLimit,
            )
          : AppleSettings(
              accuracy: LocationAccuracy.reduced,
              timeLimit: timeLimit,
            );
      final position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );

      final displayName = await ref
          .read(locationRepositoryProvider)
          .updateFromDevice(lat: position.latitude, lng: position.longitude);
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location set to ${displayName ?? "your area"}'),
          ),
        );
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(
        () => _error =
            "Couldn't get your location — try searching for your area instead.",
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Clears the stored location — the user goes back to "not set", shown as
  /// Remote to others rather than an approximate/exact pin.
  Future<void> _clearLocation() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(locationRepositoryProvider).clear();
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location removed — you now show as Remote'),
          ),
        );
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _select(LocationSuggestion s) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final displayName = await ref
          .read(locationRepositoryProvider)
          .updateFromPlaceId(s.placeId);
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location set to ${displayName ?? s.description}'),
          ),
        );
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final current = ref.watch(authControllerProvider).user?.location;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SubPageHeader(title: 'Your Location'),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.md,
                Insets.lg,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (current?.isSet ?? false) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.place_rounded,
                          size: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Currently: ${current!.displayName}',
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _busy ? null : _clearLocation,
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.sm),
                  ],
                  Text('Search for your city or area', style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'We only store a general area — never your exact address. Free-tier '
                    'viewers only ever see an approximate pin; Premium sees the same general area, un-blurred.',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _useCurrentLocation,
                      icon: const Icon(Icons.my_location_rounded, size: 16),
                      label: const Text('Use my current location'),
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  Row(
                    children: [
                      Expanded(child: Divider(color: scheme.outlineVariant)),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Insets.sm,
                        ),
                        child: Text(
                          'or',
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: scheme.outlineVariant)),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                  TextField(
                    controller: _query,
                    onChanged: _onChanged,
                    decoration: InputDecoration(
                      hintText: 'e.g. Camden, London',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: Insets.sm),
                    Text(
                      _error!,
                      style: text.bodySmall?.copyWith(
                        color: AppColors.destructive,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Insets.sm),
            Expanded(
              child: _suggestions.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.lg,
                      ),
                      itemCount: _suggestions.length,
                      itemBuilder: (context, i) {
                        final s = _suggestions[i];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.location_on_outlined,
                            color: scheme.onSurfaceVariant,
                          ),
                          title: Text(s.description, style: text.bodyMedium),
                          onTap: _busy ? null : () => _select(s),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
