/// Compile-time configuration. Override at run time, e.g.:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
///
/// Android emulator reaches the host machine at 10.0.2.2; iOS simulator uses localhost.
class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );

  /// Socket.IO origin (the API base URL without the `/api/v1` suffix).
  static String get socketOrigin =>
      apiBaseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');

  /// Socket.IO namespace used by the backend gateway.
  static const String socketNamespace = '/realtime';
}
