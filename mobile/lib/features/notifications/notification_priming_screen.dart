import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../../design_system/widgets/swappa_logo.dart';
import 'push_repository.dart';

/// Shown once, right after profile setup, before landing on [AppShell] — an
/// in-app "priming" step ahead of the real OS permission dialog, so a "no"
/// here doesn't burn the one-shot OS decision the way a cold system prompt
/// would. See [notificationPrimingNeededProvider] for when this reappears
/// (never, once the user has either decided or explicitly skipped).
class NotificationPrimingScreen extends ConsumerStatefulWidget {
  const NotificationPrimingScreen({super.key});

  @override
  ConsumerState<NotificationPrimingScreen> createState() =>
      _NotificationPrimingScreenState();
}

class _NotificationPrimingScreenState
    extends ConsumerState<NotificationPrimingScreen> {
  bool _busy = false;

  static const _perks = <(IconData, String)>[
    (
      Icons.handshake_rounded,
      'Swap requests the moment someone wants to trade',
    ),
    (Icons.schedule_rounded, 'Session reminders so you never miss a booking'),
    (Icons.chat_bubble_rounded, 'New messages when you\'re away from the app'),
  ];

  Future<void> _enable() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(pushRepositoryProvider);
      final settings = await repo.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await repo.registerToken();
      }
    } finally {
      ref.invalidate(notificationPrimingNeededProvider);
    }
  }

  Future<void> _skip() async {
    await ref.read(notificationPermissionStoreProvider).markSkipped();
    ref.invalidate(notificationPrimingNeededProvider);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: Column(
            children: [
              const Spacer(),
              const SwappaLogo(size: 56),
              const SizedBox(height: Insets.xl),
              Text(
                'Stay in the loop',
                style: text.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Insets.sm),
              Text(
                'Turn on notifications so you don\'t miss what\'s happening with your swaps.',
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Insets.xl),
              ..._perks.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: Insets.md),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(Radii.sm),
                        ),
                        child: Icon(p.$1, size: 17, color: AppColors.primary),
                      ),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: Text(
                          p.$2,
                          style: text.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _enable,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Enable notifications'),
                ),
              ),
              const SizedBox(height: Insets.sm),
              TextButton(
                onPressed: _busy ? null : _skip,
                child: Text(
                  'Not now',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
