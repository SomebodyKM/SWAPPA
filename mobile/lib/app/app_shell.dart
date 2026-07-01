import 'package:flutter/material.dart';

import '../design_system/app_colors.dart';
import '../design_system/tokens.dart';
import '../features/chat/chat_screen.dart';
import '../features/discovery/discovery_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/swaps/swaps_screen.dart';
import '../features/wallet/wallet_screen.dart';

/// The logged-in app: 5 tabs behind a rounded bottom nav (Discover, Swaps,
/// Chat, Wallet, Profile).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _tabs = <Widget>[
    DiscoveryScreen(),
    SwapsScreen(),
    ChatScreen(),
    WalletScreen(),
    ProfileScreen(),
  ];

  static const _items = <_NavItem>[
    _NavItem(Icons.search_rounded, 'Discover'),
    _NavItem(Icons.repeat_rounded, 'Swaps', badgeDot: true),
    _NavItem(Icons.chat_bubble_rounded, 'Chat', badgeCount: 2),
    _NavItem(Icons.monetization_on_rounded, 'Wallet'),
    _NavItem(Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 6),
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: _NavButton(
                      item: _items[i],
                      active: _index == i,
                      onTap: () => setState(() => _index = i),
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
  const _NavItem(this.icon, this.label, {this.badgeDot = false, this.badgeCount});
  final IconData icon;
  final String label;
  final bool badgeDot;
  final int? badgeCount;
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.active, required this.onTap});
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
                if (item.badgeDot)
                  Positioned(
                    top: -1,
                    right: -2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 2),
                      ),
                    ),
                  ),
                if (item.badgeCount != null)
                  Positioned(
                    top: -6,
                    right: -8,
                    child: Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: Text('${item.badgeCount}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(item.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    )),
          ],
        ),
      ),
    );
  }
}
