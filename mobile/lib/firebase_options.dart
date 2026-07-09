import 'package:firebase_core/firebase_core.dart';

/// Web-only Firebase config. Android/iOS keep initializing from their native
/// config files (`google-services.json` / `GoogleService-Info.plist`) via a
/// plain `Firebase.initializeApp()` — this only exists because the web SDK
/// has no equivalent native file to auto-discover and needs options passed
/// explicitly (`main.dart` picks this branch only when `kIsWeb`).
///
/// PLACEHOLDER — replace every value below with the real config from
/// Firebase Console → Project settings → General → Your apps → (add a Web
/// app if none exists) → SDK setup and configuration → Config. These values
/// are client-safe (same category as the Android api_key already committed
/// via google-services.json) — not server secrets.
class DefaultFirebaseOptions {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    authDomain: 'REPLACE_ME.firebaseapp.com',
    projectId: 'REPLACE_ME',
    storageBucket: 'REPLACE_ME.firebasestorage.app',
    messagingSenderId: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    measurementId: 'REPLACE_ME',
  );

  /// FCM web push needs its own key pair (separate from the config above) —
  /// Firebase Console → Project settings → Cloud Messaging → Web
  /// configuration → Web Push certificates. Generate one if none exists yet.
  static const String webVapidKey = 'REPLACE_ME';
}
