import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/notifications/notification_style.dart';
import '../tokens.dart';

/// The single foreground alert entry point for users who haven't granted OS
/// notification permission (see `AppShell._onNotification` for the split).
/// Only one banner is ever on screen — a newer notification replaces
/// whichever one is currently showing rather than stacking.
OverlayEntry? _currentEntry;

void showInAppNotificationPopup(
  BuildContext context, {
  required String title,
  required String body,
  required String type,
  VoidCallback? onTap,
}) {
  _currentEntry?.remove();
  _currentEntry = null;

  final overlay = Overlay.of(context);
  late final OverlayEntry entry;

  void removeFromOverlay() {
    if (identical(_currentEntry, entry)) _currentEntry = null;
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) => _NotificationPopup(
      title: title,
      body: body,
      style: styleForType(type),
      onTap: onTap,
      onDismiss: removeFromOverlay,
    ),
  );

  _currentEntry = entry;
  overlay.insert(entry);
}

class _NotificationPopup extends StatefulWidget {
  const _NotificationPopup({
    required this.title,
    required this.body,
    required this.style,
    required this.onTap,
    required this.onDismiss,
  });

  final String title;
  final String body;
  final NotificationStyle style;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  @override
  State<_NotificationPopup> createState() => _NotificationPopupState();
}

class _NotificationPopupState extends State<_NotificationPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    // Quick slide + slight overshoot bounce on entry for most notifications
    // — a "reward moment" per the design's motion rules. Warnings skip the
    // bounce (calm entry only, no bounce/confetti).
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 180),
  )..forward();

  late final Animation<Offset> _slide =
      Tween(begin: const Offset(0, -1), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _controller,
          curve: widget.style.isWarning
              ? Curves.easeOutCubic
              : Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        ),
      );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeIn,
  );

  late final Animation<double> _iconPop = widget.style.isCelebratory
      ? CurvedAnimation(parent: _controller, curve: Curves.elasticOut)
      : const AlwaysStoppedAnimation(1);

  Timer? _autoDismiss;

  @override
  void initState() {
    super.initState();
    _autoDismiss = Timer(const Duration(seconds: 4), _dismiss);
  }

  // Fast fade+slide-up exit (no bounce), then actually removed from the
  // overlay — used for auto-timeout and tap. A user swipe plays its own
  // Dismissible motion instead, so that path skips straight to removal.
  void _dismiss() {
    _autoDismiss?.cancel();
    _controller.reverse().then((_) => widget.onDismiss());
  }

  void _handleTap() {
    _autoDismiss?.cancel();
    widget.onTap?.call();
    _dismiss();
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final style = widget.style;
    return Positioned(
      top: MediaQuery.of(context).padding.top + Insets.sm,
      left: Insets.md,
      right: Insets.md,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.up,
            onDismissed: (_) {
              _autoDismiss?.cancel();
              widget.onDismiss();
            },
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.lg),
                onTap: _handleTap,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    boxShadow: [
                      // Soft, violet-tinted "lifted card" shadow.
                      BoxShadow(
                        color: const Color(0xFF5A2EE5).withValues(alpha: 0.14),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(width: 4, color: style.accentColor),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(Insets.md),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ScaleTransition(
                                  scale: _iconPop,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: style.accentColor.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      style.icon,
                                      color: style.iconColor,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: Insets.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.title,
                                        style: text.titleSmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.body,
                                        style: text.bodySmall?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
