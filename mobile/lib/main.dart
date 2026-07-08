import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_shell.dart';
import 'core/theme_provider.dart';
import 'features/admin/admin_home_screen.dart';
import 'design_system/app_theme.dart';
import 'design_system/widgets/swappa_logo.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/profile_setup_screen.dart';
import 'features/notifications/notification_navigation.dart';
import 'features/notifications/notification_presenter.dart';
import 'features/notifications/notification_priming_screen.dart';
import 'features/notifications/push_repository.dart';

/// Required by the plugin to run in a background isolate when a push arrives
/// while the app is killed/backgrounded. Firebase Admin always sends a
/// `notification` payload, so the OS already shows a system-tray banner on
/// its own — this only needs to exist, not do anything, unless custom
/// processing (e.g. updating a local badge) is added later.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
  runApp(const ProviderScope(child: SwappaApp()));
}

class SwappaApp extends ConsumerWidget {
  const SwappaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'SWAPPA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      home: const _AuthGate(),
    );
  }
}

/// Routes between the splash, login, profile/skills setup, notification
/// priming, and the logged-in app based on session. Authenticated users who
/// haven't finished the post-signup setup are sent to [ProfileSetupScreen]
/// every time — whether they just verified their email or are logging back
/// in later. [NotificationPrimingScreen] only ever shows once, per
/// [notificationPrimingNeededProvider].
///
/// Admins skip all of that — they don't swap skills or use the main app, so
/// there's no onboarding/priming/tabs to route them through. The moment
/// `role` is admin, this lands directly on [AdminHomeScreen] and stays there
/// reactively (watching [authControllerProvider] means a mid-session
/// promotion would redirect here immediately too, not just on next login).
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    switch (auth.status) {
      case AuthStatus.unknown:
        return const _Splash();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.authenticated:
        final user = auth.user;
        if (user != null && user.isAdmin) {
          return const AdminHomeScreen();
        }
        if (user != null && !user.onboardingComplete) {
          return const ProfileSetupScreen();
        }
        final primingNeeded = ref
            .watch(notificationPrimingNeededProvider)
            .asData
            ?.value;
        if (primingNeeded == null) return const _Splash();
        return primingNeeded
            ? const NotificationPrimingScreen()
            : const _AppShellWithPush();
    }
  }
}

/// The logged-in app, plus keeping the FCM token fresh for the rest of the
/// session — covers the case where permission was already granted in an
/// earlier session (so the priming screen won't show again) but the token
/// may have rotated since.
class _AppShellWithPush extends ConsumerStatefulWidget {
  const _AppShellWithPush();

  @override
  ConsumerState<_AppShellWithPush> createState() => _AppShellWithPushState();
}

class _AppShellWithPushState extends ConsumerState<_AppShellWithPush> {
  @override
  void initState() {
    super.initState();
    ref.read(pushRepositoryProvider).registerToken();

    // Tapped from the system tray while backgrounded.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
    // Tapped from a cold start (app was killed) — the message that launched
    // the app isn't delivered via onMessageOpenedApp, only this call.
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleTap(message);
    });
    // The backend falls back to FCM push whenever it thinks the recipient
    // is offline — if that check ever races with a reconnect and fires
    // while this app is still foregrounded, FCM delivers it here instead of
    // auto-showing anything (foreground pushes are never auto-displayed).
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  void _handleTap(RemoteMessage message) {
    handleNotificationTap(
      context,
      ref,
      type: message.data['type']?.toString() ?? '',
      data: message.data,
    );
  }

  void _handleForegroundMessage(RemoteMessage message) {
    handleForegroundNotification(
      context,
      ref,
      type: message.data['type']?.toString() ?? '',
      title: message.notification?.title,
      body: message.notification?.body ?? message.data['body']?.toString(),
      data: message.data,
    );
  }

  @override
  Widget build(BuildContext context) => const AppShell();
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: SwappaLogo(size: 72)));
  }
}
