import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../core/providers.dart';
import '../design_system/app_colors.dart';
import '../design_system/tokens.dart';
import '../features/auth/auth_controller.dart';
import '../features/chat/chat_repository.dart';
import '../features/chat/chat_screen.dart';
import '../features/chat/conversation.dart';
import '../features/discovery/discovery_screen.dart';
import '../features/notifications/notification_presenter.dart';
import '../features/notifications/notification_repository.dart';
import '../features/profile/profile_screen.dart';
import '../features/swaps/swaps_screen.dart';
import '../features/wallet/wallet_screen.dart';

/// The logged-in app: 5 tabs behind a rounded bottom nav (Discover, Swaps,
/// Chat, Wallet, Profile).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  // Cached rather than read from `ref` in dispose() — Riverpod forbids
  // `ref.read`/`ref.watch` once a widget is being torn down.
  io.Socket? _socket;

  static const _tabs = <Widget>[
    DiscoveryScreen(),
    SwapsScreen(),
    ChatScreen(),
    WalletScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _connectRealtime();
  }

  /// Keeps the socket connected for the whole logged-in session (not just
  /// while a chat thread is open) so the Chat tab and bell badge live-update
  /// even when the user is elsewhere in the app.
  Future<void> _connectRealtime() async {
    final socket = await ref.read(socketClientProvider).ensureConnected();
    if (!mounted) return;
    _socket = socket;
    socket.on('message:new', _onMessageNew);
    socket.on('notification', _onNotification);
  }

  /// Un-hides a swiped-away conversation the moment the *other* participant
  /// sends a new message — hiding your own outgoing message shouldn't reveal
  /// it, per the "hide until they message again" behavior.
  void _onMessageNew(dynamic data) {
    final map = (data is Map ? data['message'] : null) as Map?;
    if (map != null) {
      final msg = ChatMessage.fromJson(map.cast<String, dynamic>());
      final myUserId = ref.read(authControllerProvider).user?.id;
      if (msg.senderId != myUserId) {
        final hidden = ref.read(hiddenConversationsProvider);
        if (hidden.contains(msg.conversationId)) {
          ref.read(hiddenConversationsProvider.notifier).state = {...hidden}
            ..remove(msg.conversationId);
        }
      }
      // The currently open thread marks itself read and refreshes once that
      // ack lands (see ChatThread._markRead) — refreshing here too risks a
      // race where this refetch beats the server applying the read receipt,
      // showing a stale unread count for a conversation you're already in.
      if (msg.conversationId == activeConversationId) return;
    }
    ref.invalidate(conversationsProvider);
  }

  /// Delegates to [handleForegroundNotification] — shared with the FCM
  /// foreground path in `_AppShellWithPushState`, since both transports need
  /// the same invalidation and OS-notification/in-app-popup handling.
  void _onNotification(dynamic data) {
    if (data is! Map || !mounted) return;
    final rawData = data['data'];
    handleForegroundNotification(
      context,
      ref,
      type: data['type']?.toString() ?? '',
      title: data['title']?.toString(),
      body: data['body']?.toString(),
      data: rawData is Map ? rawData.cast<String, dynamic>() : const {},
    );
  }

  @override
  void dispose() {
    _socket?.off('message:new', _onMessageNew);
    _socket?.off('notification', _onNotification);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final index = ref.watch(appTabIndexProvider);
    final unreadChat = ref.watch(unreadChatCountProvider);
    // Same source as the bell on the Swaps screen, so the two badges can
    // never disagree.
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);
    final items = <_NavItem>[
      const _NavItem(Icons.search_rounded, 'Discover'),
      _NavItem(
        Icons.repeat_rounded,
        'Swaps',
        badgeCount: unreadNotifications > 0 ? unreadNotifications : null,
      ),
      _NavItem(
        Icons.chat_bubble_rounded,
        'Chat',
        badgeCount: unreadChat > 0 ? unreadChat : null,
      ),
      const _NavItem(Icons.monetization_on_rounded, 'Wallet'),
      const _NavItem(Icons.person_rounded, 'Profile'),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: _tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.sm,
              vertical: 6,
            ),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavButton(
                      item: items[i],
                      active: index == i,
                      onTap: () =>
                          ref.read(appTabIndexProvider.notifier).state = i,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.label, {this.badgeCount});
  final IconData icon;
  final String label;
  final int? badgeCount;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.active,
    required this.onTap,
  });
  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? AppColors.primary : scheme.onSurfaceVariant;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(item.icon, size: 22, color: color),
                if (item.badgeCount != null)
                  Positioned(
                    top: -6,
                    right: -8,
                    child: Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${item.badgeCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
