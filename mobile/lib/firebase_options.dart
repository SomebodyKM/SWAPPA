import 'package:firebase_core/firebase_core.dart';

/// Web-only Firebase config. Android/iOS keep initializing from their native
/// config files (`google-services.json` / `GoogleService-Info.plist`) via a
/// plain `Firebase.initializeApp()` — this only exists because the web SDK
/// has no equivalent native file to auto-discover and needs options passed
/// explicitly (`main.dart` picks this branch only when `kIsWeb`).
///
class DefaultFirebaseOptions {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC0RHsg6tIiq04sN4zhlhfSCUODkTw5Swg',
    authDomain: 'swappa-fbe10.firebaseapp.com',
    projectId: 'swappa-fbe10',
    storageBucket: 'swappa-fbe10.firebasestorage.app',
    messagingSenderId: '543967755108',
    appId: '1:543967755108:web:7f5ac1534db994f272d871',
    measurementId: 'G-TVX55JBWH8',
  );

  /// FCM web push needs its own key pair (separate from the config above) —
  /// Firebase Console → Project settings → Cloud Messaging → Web
  /// configuration → Web Push certificates.
  static const String webVapidKey =
      'BLOxEQpOPJyRnZEU0RtecSMYuLZ-JkV93wqMZTtTCR1DTQyxf10-ga4Fg7scsmeysJoDcND39jcGo5qUt809uFk';
}
