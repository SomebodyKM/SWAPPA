import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Remembers whether the user explicitly dismissed the notification-priming
/// screen with "Not now" — distinct from the OS permission status itself,
/// since skipping never asks the OS at all (status stays `notDetermined`,
/// which would otherwise show the priming screen again every launch).
class NotificationPermissionStore {
  NotificationPermissionStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _skippedKey = 'swappa.notification_priming_skipped';
  static const _enabledKey = 'swappa.notifications_enabled';

  Future<bool> get wasSkipped async =>
      (await _storage.read(key: _skippedKey)) == 'true';

  Future<void> markSkipped() => _storage.write(key: _skippedKey, value: 'true');

  /// The Settings-screen toggle's own on/off preference — distinct from the
  /// OS authorization status, since that can only ever be granted or denied,
  /// never freely flipped back and forth the way a switch needs to be. Null
  /// means no explicit choice yet (falls back to whatever the OS reports).
  Future<bool?> get enabledPreference async {
    final raw = await _storage.read(key: _enabledKey);
    if (raw == null) return null;
    return raw == 'true';
  }

  Future<void> setEnabled(bool enabled) =>
      _storage.write(key: _enabledKey, value: enabled.toString());
}
