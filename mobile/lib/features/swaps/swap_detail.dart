import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../../design_system/widgets/avatar.dart';
import '../../design_system/widgets/status_badge.dart';
import '../auth/auth_controller.dart';
import '../profile/models/review.dart';
import '../profile/profile_providers.dart';
import 'edit_swap_sheet.dart';
import 'end_swap_dialog.dart';
import 'propose_session_sheet.dart';
import 'review_sheet.dart';
import 'swap_repository.dart';

class SwapDetail extends ConsumerStatefulWidget {
  const SwapDetail({super.key, required this.swapId});
  final String swapId;

  @override
  ConsumerState<SwapDetail> createState() => _SwapDetailState();
}

class _SwapDetailState extends ConsumerState<SwapDetail> {
  // Cached rather than read from `ref` in dispose() — Riverpod forbids
  // `ref.read`/`ref.watch` once a widget is being torn down.
  io.Socket? _socket;

  String get _myUserId => ref.read(authControllerProvider).user?.id ?? '';

  @override
  void initState() {
    super.initState();
    _bindSocket();
  }

  Future<void> _bindSocket() async {
    final socket = await ref.read(socketClientProvider).ensureConnected();
    if (!mounted) return;
    _socket = socket;
    socket.on('notification', _onNotification);
  }

  void _onNotification(dynamic data) {
    final type = (data is Map) ? data['type']?.toString() : null;
    if (type == null || !kSwapRelatedNotificationTypes.contains(type)) return;
    _invalidateAll();
  }

  void _invalidateAll() {
    ref.invalidate(swapByIdProvider(widget.swapId));
    ref.invalidate(swapSessionsProvider(widget.swapId));
    ref.invalidate(mySwapsProvider);
    ref.invalidate(upcomingSessionsProvider);
  }

  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
      _invalidateAll();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _proposeSession(SwapRecord swap) async {
    final result = await showProposeSessionSheet(
      context,
      partnerName: swap.otherUserName,
    );
    if (result == null) return;
    final myUserId = _myUserId;
    final teacherId = result.iTeach ? myUserId : swap.otherUserId;
    final learnerId = result.iTeach ? swap.otherUserId : myUserId;
    await _act(
      () => ref
          .read(swapRepositoryProvider)
          .proposeSession(
            swapId: swap.id,
            teacherId: teacherId,
            learnerId: learnerId,
            scheduledAt: result.scheduledAt,
            format: result.format,
          ),
    );
  }

  Future<void> _decline(SwapRecord swap) async {
    final reason = await promptCancelSwap(
      context,
      reasonRequired: swap.cancelNeedsReason(_myUserId),
      title: 'Decline this request?',
      body: 'Let ${swap.otherUserName} know why you’re declining.',
      confirmLabel: 'Decline',
    );
    if (reason == null) return;
    await _act(
      () => ref
          .read(swapRepositoryProvider)
          .cancel(_myUserId, swap.id, reason: reason),
    );
  }

  Future<void> _endSwap(SwapRecord swap) async {
    final reason = await promptCancelSwap(
      context,
      reasonRequired: swap.cancelNeedsReason(_myUserId),
    );
    if (reason == null) return;
    await _act(
      () => ref
          .read(swapRepositoryProvider)
          .cancel(_myUserId, swap.id, reason: reason),
    );
  }

  Future<void> _markFinished(SwapRecord swap) => _act(
    () => ref.read(swapRepositoryProvider).confirmFinish(_myUserId, swap.id),
  );

  Future<void> _editSwap(SwapRecord swap) async {
    final saved = await showEditSwapSheet(context, ref, swap: swap);
    if (saved) _invalidateAll();
  }

  Future<void> _abandon(SwapRecord swap) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        title: const Text('Abandon this swap?'),
        content: Text(
          '${swap.otherUserName} was reported as a no-show and the grace window has passed. '
          'This ends the swap for both of you and frees up your active-swap slot.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            child: const Text('Abandon'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _act(
      () => ref.read(swapRepositoryProvider).abandon(_myUserId, swap.id),
    );
  }

  Future<void> _reportNoShow(SwapSession session) =>
      _act(() => ref.read(swapRepositoryProvider).reportNoShow(session.id));

  @override
  void dispose() {
    _socket?.off('notification', _onNotification);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final swapAsync = ref.watch(swapByIdProvider(widget.swapId));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: swapAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _DetailError(onBack: () => Navigator.pop(context)),
          data: (swap) => _DetailBody(
            swap: swap,
            myUserId: _myUserId,
            onAct: _act,
            onProposeSession: () => _proposeSession(swap),
            onDecline: () => _decline(swap),
            onEndSwap: () => _endSwap(swap),
            onMarkFinished: () => _markFinished(swap),
            onEditSwap: () => _editSwap(swap),
            onAbandon: () => _abandon(swap),
            onReportNoShow: _reportNoShow,
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({
    required this.swap,
    required this.myUserId,
    required this.onAct,
    required this.onProposeSession,
    required this.onDecline,
    required this.onEndSwap,
    required this.onMarkFinished,
    required this.onEditSwap,
    required this.onAbandon,
    required this.onReportNoShow,
  });

  final SwapRecord swap;
  final String myUserId;
  final Future<void> Function(Future<void> Function()) onAct;
  final VoidCallback onProposeSession;
  final VoidCallback onDecline;
  final VoidCallback onEndSwap;
  final VoidCallback onMarkFinished;
  final VoidCallback onEditSwap;
  final VoidCallback onAbandon;
  final ValueChanged<SwapSession> onReportNoShow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final sessionsAsync = ref.watch(swapSessionsProvider(swap.id));
    final repo = ref.read(swapRepositoryProvider);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(
            Insets.lg,
            Insets.sm,
            Insets.lg,
            Insets.md,
          ),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Row(
            children: [
              _CircleIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(width: Insets.md),
              Avatar(
                initials: swap.initials,
                color: avatarColorFor(swap.otherUserId),
                size: 36,
                photoUrl: swap.otherUserPhotoUrl,
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      swap.otherUserName,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${swap.myTeachSkill(myUserId).name} ↔ ${swap.myLearnSkill(myUserId).name}',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              StatusBadge(status: swap.badgeStatus),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(Insets.lg),
            children: [
              if (swap.status == 'requested') ...[
                _SectionCard(
                  title: 'Swap request',
                  child: swap.isInitiator(myUserId)
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Waiting for ${swap.otherUserName} to accept.',
                              style: text.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: Insets.sm),
                            _OutlineAction(
                              icon: Icons.edit_outlined,
                              label: 'Edit terms',
                              onTap: onEditSwap,
                            ),
                            const SizedBox(height: Insets.sm),
                            _OutlineAction(
                              icon: Icons.close_rounded,
                              label: 'Withdraw request',
                              color: AppColors.destructive,
                              onTap: () =>
                                  onAct(() => repo.cancel(myUserId, swap.id)),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: onDecline,
                                child: const Text('Decline'),
                              ),
                            ),
                            const SizedBox(width: Insets.sm),
                            Expanded(
                              child: FilledButton(
                                onPressed: () =>
                                    onAct(() => repo.accept(myUserId, swap.id)),
                                child: const Text('Accept'),
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: Insets.lg),
              ],
              if (swap.status == 'cancelled' && swap.cancelReason != null) ...[
                _SectionCard(
                  title: 'Cancelled',
                  icon: Icons.info_outline_rounded,
                  child: Text(
                    swap.cancelReason!,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: Insets.lg),
              ],
              _SectionCard(
                title: 'Sessions',
                icon: Icons.schedule_rounded,
                child: sessionsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) =>
                      Text('Couldn’t load sessions', style: text.bodySmall),
                  data: (sessions) {
                    final completedCount = sessions
                        .where((s) => s.status == 'completed')
                        .length;
                    final pending = sessions.where((s) => s.isPending).toList()
                      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
                    final past = sessions.where((s) => !s.isPending).toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final s in pending)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Insets.md),
                            child: _SessionTile(
                              session: s,
                              myUserId: myUserId,
                              otherUserName: swap.otherUserName,
                              onRespond: (d) =>
                                  onAct(() => repo.respondSession(s.id, d)),
                              onConfirmComplete: () => onAct(
                                () => repo.confirmCompleteSession(s.id),
                              ),
                              onCancel: () =>
                                  onAct(() => repo.cancelSession(s.id)),
                              onReportNoShow: () => onReportNoShow(s),
                            ),
                          ),
                        Text(
                          '$completedCount session${completedCount == 1 ? '' : 's'} completed',
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (past.isNotEmpty) ...[
                          const SizedBox(height: Insets.sm),
                          for (final s in past) _SessionHistoryRow(session: s),
                        ],
                      ],
                    );
                  },
                ),
              ),
              if (swap.status == 'active') ...[
                const SizedBox(height: Insets.lg),
                _SectionCard(
                  title: 'Actions',
                  child: Column(
                    children: [
                      _OutlineAction(
                        icon: Icons.add_rounded,
                        label: 'Propose new session',
                        onTap: onProposeSession,
                      ),
                      const SizedBox(height: Insets.sm),
                      _FinishSwapAction(
                        swap: swap,
                        myUserId: myUserId,
                        onConfirm: onMarkFinished,
                      ),
                      // Only ever shown once a reported no-show's grace
                      // window has actually elapsed — otherwise this isn't
                      // callable at all, per the backend.
                      if (swap.canAbandon) ...[
                        const SizedBox(height: Insets.sm),
                        _OutlineAction(
                          icon: Icons.flag_outlined,
                          label: 'Abandon swap (no-show)',
                          color: AppColors.destructive,
                          onTap: onAbandon,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: Insets.lg),
                Center(
                  child: TextButton(
                    onPressed: onEndSwap,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.destructive,
                    ),
                    child: const Text('End swap'),
                  ),
                ),
              ],
              if (swap.status == 'completed') ...[
                const SizedBox(height: Insets.lg),
                _ReviewSection(swap: swap),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Mutual "mark finished" for the swap itself — mirrors [_SessionTile]'s
/// confirm-complete two-step, but at the swap level (not tied to one session).
class _FinishSwapAction extends StatefulWidget {
  const _FinishSwapAction({
    required this.swap,
    required this.myUserId,
    required this.onConfirm,
  });
  final SwapRecord swap;
  final String myUserId;
  final VoidCallback onConfirm;

  @override
  State<_FinishSwapAction> createState() => _FinishSwapActionState();
}

class _FinishSwapActionState extends State<_FinishSwapAction> {
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final iConfirmed = widget.swap.hasConfirmedFinish(widget.myUserId);
    final otherConfirmed = widget.swap.finishConfirmedBy.contains(
      widget.swap.otherUserId,
    );

    if (iConfirmed) {
      return _OutlineAction(
        icon: Icons.hourglass_top_rounded,
        label: 'Waiting for ${widget.swap.otherUserName} to confirm finished',
        onTap: () {},
      );
    }
    // The other side already confirmed — surface that clearly, since your
    // tap here is the one that actually completes the swap.
    if (otherConfirmed) {
      return Container(
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.swap.otherUserName} marked this swap finished.',
              style: text.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.offerFg,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Confirm if you agree — this completes the swap.',
              style: text.bodySmall?.copyWith(color: AppColors.offerFg),
            ),
            const SizedBox(height: Insets.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: widget.onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  minimumSize: const Size(0, 38),
                ),
                child: const Text('Confirm finished'),
              ),
            ),
          ],
        ),
      );
    }
    if (!_confirming) {
      return _OutlineAction(
        icon: Icons.check_circle_outline_rounded,
        label: 'Mark finished',
        color: AppColors.success,
        onTap: () => setState(() => _confirming = true),
      );
    }
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Both you and ${widget.swap.otherUserName} must mark this finished to complete the swap.',
            style: text.bodySmall?.copyWith(color: AppColors.offerFg),
          ),
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: widget.onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    minimumSize: const Size(0, 38),
                  ),
                  child: const Text('Confirm finished'),
                ),
              ),
              const SizedBox(width: Insets.sm),
              OutlinedButton(
                onPressed: () => setState(() => _confirming = false),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown once a swap is completed — lets either side leave a review, or
/// edit/delete the one they already left. `myReviewForSwapProvider` is how
/// we know which state to show without guessing from a failed POST.
class _ReviewSection extends ConsumerWidget {
  const _ReviewSection({required this.swap});
  final SwapRecord swap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final reviewAsync = ref.watch(myReviewForSwapProvider(swap.id));

    Future<void> openSheet(MyReview? existing) async {
      final saved = await showReviewSheet(
        context,
        swapId: swap.id,
        otherUserName: swap.otherUserName,
        existing: existing,
      );
      if (saved) {
        ref.invalidate(myReviewForSwapProvider(swap.id));
        // The reviewee's rating/review list changed too — refresh wherever
        // that's shown (their public profile popup, discovery card, etc.).
        ref.invalidate(userReviewsProvider(swap.otherUserId));
        ref.invalidate(publicProfileProvider(swap.otherUserId));
      }
    }

    return _SectionCard(
      title: 'Review',
      icon: Icons.star_outline_rounded,
      child: reviewAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) =>
            Text('Couldn’t load review status', style: text.bodySmall),
        data: (review) {
          if (review == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How was swapping with ${swap.otherUserName}?',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Insets.sm),
                _OutlineAction(
                  icon: Icons.star_outline_rounded,
                  label: 'Leave a review',
                  onTap: () => openSheet(null),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (var i = 1; i <= 5; i++)
                    Icon(
                      i <= review.rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 18,
                      color: AppColors.accent,
                    ),
                ],
              ),
              if (review.comment != null && review.comment!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  review.comment!,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: Insets.sm),
              _OutlineAction(
                icon: Icons.edit_outlined,
                label: 'Edit your review',
                onTap: () => openSheet(review),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40),
            const SizedBox(height: Insets.md),
            Text(
              'Couldn’t load this swap',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Insets.lg),
            OutlinedButton(onPressed: onBack, child: const Text('Back')),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: scheme.onSurface),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, this.icon, required this.child});
  final String title;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: AppColors.primary),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          child,
        ],
      ),
    );
  }
}

/// A "proposed" or "accepted" session — the only two statuses that still need
/// someone's action (respond / confirm complete).
class _SessionTile extends StatefulWidget {
  const _SessionTile({
    required this.session,
    required this.myUserId,
    required this.otherUserName,
    required this.onRespond,
    required this.onConfirmComplete,
    required this.onCancel,
    required this.onReportNoShow,
  });

  final SwapSession session;
  final String myUserId;
  final String otherUserName;
  final ValueChanged<String> onRespond; // 'accept' | 'decline'
  final VoidCallback onConfirmComplete;
  final VoidCallback onCancel;
  final VoidCallback onReportNoShow;

  @override
  State<_SessionTile> createState() => _SessionTileState();
}

class _SessionTileState extends State<_SessionTile> {
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = widget.session;
    final iAmProposer = s.isProposer(widget.myUserId);
    final iConfirmed = s.hasConfirmed(widget.myUserId);
    final otherUserId = s.teacherId == widget.myUserId
        ? s.learnerId
        : s.teacherId;
    final otherConfirmed = s.confirmedBy.contains(otherUserId);

    Widget actions;
    if (s.status == 'proposed' && !iAmProposer) {
      actions = Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => widget.onRespond('decline'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32)),
              child: const Text('Decline'),
            ),
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: FilledButton(
              onPressed: () => widget.onRespond('accept'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 32)),
              child: const Text('Accept'),
            ),
          ),
        ],
      );
    } else if (s.status == 'proposed') {
      actions = Row(
        children: [
          Expanded(
            child: Text(
              'Waiting for ${widget.otherUserName} to respond',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
        ],
      );
    } else if (iConfirmed) {
      // My side is locked in — only Cancel remains actionable until the
      // other person confirms too (or this session is cancelled outright).
      actions = Row(
        children: [
          Expanded(
            child: Text(
              'Waiting for ${widget.otherUserName} to confirm',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
        ],
      );
    } else if (otherConfirmed) {
      // The other side already confirmed — surface that clearly, since your
      // tap here is the one that actually completes the session.
      actions = Container(
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.otherUserName} marked this session complete.',
              style: text.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.offerFg,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Confirm if you agree.',
              style: text.bodySmall?.copyWith(color: AppColors.offerFg),
            ),
            const SizedBox(height: Insets.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: widget.onConfirmComplete,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  minimumSize: const Size(0, 38),
                ),
                child: const Text('Confirm complete'),
              ),
            ),
          ],
        ),
      );
    } else if (!_confirming) {
      actions = Row(
        children: [
          Expanded(
            child: Text(
              'Happened already?',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _confirming = true),
            child: const Text('Mark complete'),
          ),
        ],
      );
    } else {
      actions = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Both you and ${widget.otherUserName} must confirm to complete this session.',
            style: text.bodySmall?.copyWith(color: AppColors.offerFg),
          ),
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: widget.onConfirmComplete,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Text('Confirm complete'),
                ),
              ),
              const SizedBox(width: Insets.sm),
              OutlinedButton(
                onPressed: () => setState(() => _confirming = false),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.status == 'proposed' ? 'Proposed' : 'Upcoming',
            style: text.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            s.whenLabel,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            '${s.formatLabel} · ${s.isTeacher(widget.myUserId) ? 'You teach' : 'You learn'}',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Insets.sm),
          actions,
          // A no-show can only be reported once the scheduled time has
          // actually passed — offered alongside whatever the normal
          // respond/confirm flow already shows, not instead of it.
          if (s.scheduledAt.isBefore(DateTime.now())) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.onReportNoShow,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.destructive,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 28),
                ),
                child: const Text(
                  'Report a no-show',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A completed/declined/cancelled/no-show session — just a record now.
class _SessionHistoryRow extends StatelessWidget {
  const _SessionHistoryRow({required this.session});
  final SwapSession session;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${session.whenLabel} · ${session.formatLabel}',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          StatusBadge(
            status: session.status == 'no_show' ? 'cancelled' : session.status,
          ),
        ],
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.onSurface;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15, color: c),
        label: Text(label, style: TextStyle(color: c)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          side: BorderSide(
            color: color?.withValues(alpha: 0.4) ?? scheme.outlineVariant,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
        ),
      ),
    );
  }
}
