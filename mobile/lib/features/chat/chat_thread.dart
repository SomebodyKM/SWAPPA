import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../../design_system/widgets/avatar.dart';
import '../ai/ai_sheet.dart';
import '../ai/paywall_sheet.dart';
import '../auth/auth_controller.dart';
import '../profile/public_profile_sheet.dart';
import '../safety/safety_repository.dart';
import '../swaps/end_swap_dialog.dart';
import '../swaps/propose_session_sheet.dart';
import '../swaps/propose_swap_sheet.dart';
import '../swaps/swap_repository.dart';
import 'chat_repository.dart';
import 'conversation.dart';

/// Finds/creates the conversation with [targetUserId] and opens it — used by
/// the "Message" action on Discovery cards. Surfaces backend errors (e.g.
/// messaging a user who's blocked you) as a snackbar instead of navigating.
/// [initialDraft] pre-fills the compose box (e.g. an AI-generated icebreaker
/// picked from Discovery, where there's no compose box to drop it into
/// directly the way there is from inside an existing thread).
Future<void> openChatWith(
  BuildContext context,
  WidgetRef ref,
  String targetUserId, {
  String? initialDraft,
}) async {
  final myUserId = ref.read(authControllerProvider).user?.id;
  if (myUserId == null) return;
  try {
    final conv = await ref
        .read(chatRepositoryProvider)
        .getOrCreate(targetUserId, myUserId);
    ref.invalidate(conversationsProvider);
    if (initialDraft != null && initialDraft.isNotEmpty) {
      ref.read(chatDraftProvider(conv.id).notifier).state = initialDraft;
    }
    if (context.mounted) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => ChatThread(conversation: conv)));
    }
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class ChatThread extends ConsumerStatefulWidget {
  const ChatThread({super.key, required this.conversation});
  final Conversation conversation;

  @override
  ConsumerState<ChatThread> createState() => _ChatThreadState();
}

class _ChatThreadState extends ConsumerState<ChatThread> {
  final List<ChatMessage> _messages = [];
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _loading = true;
  bool _sending = false;
  String? _error;
  // Cached rather than read from `ref` in dispose() — Riverpod forbids
  // `ref.read`/`ref.watch` once a widget is being torn down.
  io.Socket? _socket;

  String get _myUserId => ref.read(authControllerProvider).user?.id ?? '';

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(chatDraftProvider(widget.conversation.id));
    _controller.addListener(_onDraftChanged);
    activeConversationId = widget.conversation.id;
    _init();
  }

  /// Persists whatever's typed but not yet sent, so it's restored if the
  /// user backs out of this thread and reopens it later (this session).
  void _onDraftChanged() {
    ref.read(chatDraftProvider(widget.conversation.id).notifier).state =
        _controller.text;
  }

  Future<void> _init() async {
    // Realtime connects first so `_socket` is already set by the time
    // `_loadMessages()` calls `_markRead()` — otherwise that first mark-read
    // (the one that clears whatever was unread before this thread was
    // opened) silently no-ops on a null socket and the unread count never
    // actually clears.
    await _connectRealtime();
    await _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final messages = await ref
          .read(chatRepositoryProvider)
          .listMessages(widget.conversation.id);
      if (mounted) {
        setState(() {
          _messages
            ..clear()
            ..addAll(messages);
        });
        _scrollToBottom();
        _markRead();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Explicitly joins this conversation's room — the socket only auto-joins
  /// rooms for conversations that already existed when it first connected,
  /// so a just-created conversation needs this to get realtime updates.
  Future<void> _connectRealtime() async {
    final socket = await ref.read(socketClientProvider).ensureConnected();
    if (!mounted) return;
    _socket = socket;
    socket.emitWithAck('conversation:join', {
      'conversationId': widget.conversation.id,
    });
    socket.on('message:new', _onMessageNew);
    socket.on('message:updated', _onMessageUpdated);
    socket.on('message:deleted', _onMessageDeleted);
  }

  void _onMessageNew(dynamic data) {
    final map = (data as Map)['message'] as Map?;
    if (map == null) return;
    final msg = ChatMessage.fromJson(map.cast<String, dynamic>());
    // The socket is joined to every conversation's room, not just this one.
    if (msg.conversationId != widget.conversation.id) return;
    if (!mounted || _messages.any((m) => m.id == msg.id)) return;
    setState(() => _messages.add(msg));
    _scrollToBottom();
    if (msg.senderId != _myUserId) _markRead();
  }

  void _onMessageUpdated(dynamic data) {
    final map = data as Map;
    final id = map['messageId']?.toString();
    final idx = _messages.indexWhere((m) => m.id == id);
    if (idx == -1 || !mounted) return;
    setState(
      () => _messages[idx] = _messages[idx].copyWith(
        body: map['body'] as String?,
        editedAt: DateTime.now(),
      ),
    );
  }

  void _onMessageDeleted(dynamic data) {
    final id = (data as Map)['messageId']?.toString();
    final idx = _messages.indexWhere((m) => m.id == id);
    if (idx == -1 || !mounted) return;
    setState(
      () => _messages[idx] = _messages[idx].copyWith(deletedAt: DateTime.now()),
    );
  }

  // Awaits the server's ack before refreshing the conversations list —
  // AppShell skips its own refresh for whichever conversation is currently
  // open (see AppShell._onMessageNew) precisely so this is the only refetch
  // for it, landing only once `readBy` has actually been updated. Without
  // that ordering, a refetch could beat the read receipt and show a stale
  // unread count for the thread you're already looking at.
  Future<void> _markRead() async {
    if (_messages.isEmpty || _socket == null) return;
    final response = await _socket!.emitWithAckAsync('message:read', {
      'conversationId': widget.conversation.id,
      'lastReadMessageId': _messages.last.id,
    });
    if (!mounted) return;
    if (response is Map && response['ok'] == true) {
      ref.invalidate(conversationsProvider);
    }
  }

  Future<void> _send() async {
    final t = _controller.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    try {
      final msg = await ref
          .read(chatRepositoryProvider)
          .sendMessage(widget.conversation.id, t);
      if (mounted && !_messages.any((m) => m.id == msg.id)) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Long-press context menu for your own messages — Edit / Delete, LINE-style.
  Future<void> _showMessageMenu(
    Offset globalPosition,
    ChatMessage message,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(globalPosition, globalPosition),
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      items: [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 16),
              SizedBox(width: 10),
              Text('Edit'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: 16,
                color: AppColors.destructive,
              ),
              SizedBox(width: 10),
              Text('Delete', style: TextStyle(color: AppColors.destructive)),
            ],
          ),
        ),
      ],
    );
    if (!mounted) return;
    if (selected == 'edit') _editMessage(message);
    if (selected == 'delete') _confirmDelete(message);
  }

  Future<void> _editMessage(ChatMessage message) async {
    final editController = TextEditingController(text: message.body ?? '');
    final newBody = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        title: const Text('Edit message'),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, editController.text.trim()),
            style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newBody == null ||
        newBody.isEmpty ||
        newBody == message.body ||
        !mounted) {
      return;
    }
    try {
      final updated = await ref
          .read(chatRepositoryProvider)
          .editMessage(message.id, newBody);
      final idx = _messages.indexWhere((m) => m.id == message.id);
      if (idx != -1 && mounted) setState(() => _messages[idx] = updated);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _confirmDelete(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        title: const Text('Delete message?'),
        content: const Text(
          'This deletes it for both of you. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
              minimumSize: const Size(64, 40),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(chatRepositoryProvider).deleteMessage(message.id);
      final idx = _messages.indexWhere((m) => m.id == message.id);
      if (idx != -1 && mounted) {
        setState(
          () => _messages[idx] = _messages[idx].copyWith(
            deletedAt: DateTime.now(),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _useIcebreaker(String otherUserId) async {
    final text = await showAiSheet(
      context,
      'icebreaker',
      matchUserId: otherUserId,
    );
    // Setting .text already notifies the listener that persists the draft.
    if (text != null && mounted) _controller.text = text;
  }

  Future<void> _proposeSwap() async {
    final c = widget.conversation;
    final created = await showProposeSwapSheet(
      context,
      ref,
      partnerId: c.otherUserId,
      partnerName: c.otherUserName,
    );
    if (created && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Swap request sent to ${c.otherUserName}')),
      );
    }
  }

  @override
  void dispose() {
    _socket?.off('message:new', _onMessageNew);
    _socket?.off('message:updated', _onMessageUpdated);
    _socket?.off('message:deleted', _onMessageDeleted);
    _controller.removeListener(_onDraftChanged);
    _controller.dispose();
    _scroll.dispose();
    if (activeConversationId == widget.conversation.id) {
      activeConversationId = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final c = widget.conversation;

    return Scaffold(
      body: SafeArea(
        child: Column(
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
                border: Border(
                  bottom: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  _circleBtn(
                    context,
                    Icons.arrow_back_rounded,
                    () => Navigator.pop(context),
                  ),
                  const SizedBox(width: Insets.md),
                  Avatar(
                    initials: c.initials,
                    color: avatarColorFor(c.otherUserId),
                    size: 36,
                    photoUrl: c.otherUserPhotoUrl,
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => showPublicProfileSheet(
                        context,
                        ref,
                        userId: c.otherUserId,
                        showMessageButton: false,
                      ),
                      child: Text(
                        c.otherUserName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  _circleBtn(context, Icons.repeat_rounded, _proposeSwap),
                  const SizedBox(width: Insets.sm),
                  _BreakIceButton(onTap: () => _useIcebreaker(c.otherUserId)),
                  _ThreadMenu(
                    otherUserId: c.otherUserId,
                    otherUserName: c.otherUserName,
                  ),
                ],
              ),
            ),
            _SwapBanner(partnerId: c.otherUserId, myUserId: _myUserId),
            // Messages
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _ThreadError(message: _error!, onRetry: _loadMessages)
                  : _messages.isEmpty
                  ? Center(
                      child: Text(
                        'Say hi 👋',
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.lg,
                        vertical: Insets.md,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final m = _messages[i];
                        final mine = m.isFromMe(_myUserId);
                        return GestureDetector(
                          onLongPressStart: mine && !m.isDeleted
                              ? (details) =>
                                    _showMessageMenu(details.globalPosition, m)
                              : null,
                          child: _Bubble(message: m, isMine: mine),
                        );
                      },
                    ),
            ),
            // Input
            _InputBar(
              controller: _controller,
              onSend: _send,
              sending: _sending,
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleBtn(BuildContext context, IconData icon, VoidCallback onTap) {
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

/// Pinned "ongoing swap" status card — kept visually separate from the
/// message list so a proposed/active swap doesn't read as just another chat
/// bubble. Collapsed, it only shows the traded skills; expanded (tap to
/// toggle) it adds status, the next session's date/time/format, and who
/// teaches what. Renders nothing when there's no open swap with this partner.
class _SwapBanner extends ConsumerStatefulWidget {
  const _SwapBanner({required this.partnerId, required this.myUserId});
  final String partnerId;
  final String myUserId;

  @override
  ConsumerState<_SwapBanner> createState() => _SwapBannerState();
}

class _SwapBannerState extends ConsumerState<_SwapBanner> {
  bool _expanded = false;
  bool _confirmingFinish = false;
  // Cached rather than read from `ref` in dispose() — Riverpod forbids
  // `ref.read`/`ref.watch` once a widget is being torn down.
  io.Socket? _socket;

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
    ref.invalidate(openSwapWithPartnerProvider(widget.partnerId));
    ref.invalidate(mySwapsProvider);
    ref.invalidate(upcomingSessionsProvider);
    final swap = ref
        .read(openSwapWithPartnerProvider(widget.partnerId))
        .asData
        ?.value;
    if (swap != null) ref.invalidate(swapSessionsProvider(swap.id));
  }

  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
      ref.invalidate(openSwapWithPartnerProvider(widget.partnerId));
      ref.invalidate(mySwapsProvider);
      ref.invalidate(upcomingSessionsProvider);
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
    await _act(
      () => ref
          .read(swapRepositoryProvider)
          .proposeSession(
            swapId: swap.id,
            teacherId: result.iTeach ? widget.myUserId : swap.otherUserId,
            learnerId: result.iTeach ? swap.otherUserId : widget.myUserId,
            scheduledAt: result.scheduledAt,
            format: result.format,
          ),
    );
    ref.invalidate(swapSessionsProvider(swap.id));
  }

  Future<void> _respondSession(String sessionId, String decision) => _act(
    () => ref.read(swapRepositoryProvider).respondSession(sessionId, decision),
  );

  Future<void> _decline(SwapRecord swap) async {
    final reason = await promptCancelSwap(
      context,
      reasonRequired: swap.cancelNeedsReason(widget.myUserId),
      title: 'Decline this request?',
      body: 'Let ${swap.otherUserName} know why you’re declining.',
      confirmLabel: 'Decline',
    );
    if (reason == null) return;
    await _act(
      () => ref
          .read(swapRepositoryProvider)
          .cancel(widget.myUserId, swap.id, reason: reason),
    );
  }

  Future<void> _endSwap(SwapRecord swap) async {
    final reason = await promptCancelSwap(
      context,
      reasonRequired: swap.cancelNeedsReason(widget.myUserId),
    );
    if (reason == null) return;
    await _act(
      () => ref
          .read(swapRepositoryProvider)
          .cancel(widget.myUserId, swap.id, reason: reason),
    );
  }

  @override
  void dispose() {
    _socket?.off('notification', _onNotification);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final async = ref.watch(openSwapWithPartnerProvider(widget.partnerId));

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (swap) {
        if (swap == null) return const SizedBox.shrink();
        final myUserId = widget.myUserId;
        final repo = ref.read(swapRepositoryProvider);
        final iAmInitiator = swap.isInitiator(myUserId);
        final requested = swap.status == 'requested';
        final iConfirmedFinish = swap.hasConfirmedFinish(myUserId);
        final otherConfirmedFinish = swap.finishConfirmedBy.contains(
          swap.otherUserId,
        );

        final String status = !requested
            ? 'Swap active'
            : iAmInitiator
            ? 'Waiting for them to accept'
            : 'Wants to swap skills with you';

        // Only the low-stakes, unconditional actions are always visible —
        // ending an active swap needs a reason, so it's tucked below the
        // fold instead of sitting next to Accept/Decline.
        final actions = <Widget>[
          if (requested && !iAmInitiator) ...[
            TextButton(
              onPressed: () => _decline(swap),
              child: const Text('Decline'),
            ),
            FilledButton(
              onPressed: () => _act(() => repo.accept(myUserId, swap.id)),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 32)),
              child: const Text('Accept'),
            ),
          ] else if (requested)
            OutlinedButton(
              onPressed: () => _act(() => repo.cancel(myUserId, swap.id)),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32)),
              child: const Text('Withdraw'),
            ),
        ];

        return Container(
          margin: const EdgeInsets.fromLTRB(Insets.lg, Insets.sm, Insets.lg, 0),
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.repeat_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Skill Swap',
                                style: text.labelMedium?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${swap.myTeachSkill(myUserId).name} ↔ ${swap.myLearnSkill(myUserId).name}',
                            style: text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Ending an active swap needs a reason, so it's tucked
                  // behind a menu rather than sitting next to Accept/Decline.
                  if (!requested)
                    _EndSwapMenu(onSelected: () => _endSwap(swap)),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, top: 2),
                      child: Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: Insets.md),
                Divider(height: 1, color: scheme.outlineVariant),
                const SizedBox(height: Insets.md),
                _LabeledValue(label: 'Status', value: status),
                const SizedBox(height: Insets.sm),
                Consumer(
                  builder: (context, ref, _) {
                    final sessionsAsync = ref.watch(
                      swapSessionsProvider(swap.id),
                    );
                    return sessionsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (e, _) => const SizedBox.shrink(),
                      data: (sessions) {
                        final pending =
                            sessions.where((s) => s.isPending).toList()..sort(
                              (a, b) => a.scheduledAt.compareTo(b.scheduledAt),
                            );
                        final next = pending.isEmpty ? null : pending.first;
                        final iAmProposer =
                            next != null && next.isProposer(myUserId);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _LabeledValue(
                                    label: 'Date & time',
                                    value: next == null
                                        ? 'Not scheduled'
                                        : next.whenLabel,
                                  ),
                                ),
                                if (next != null)
                                  Expanded(
                                    child: _LabeledValue(
                                      label: 'Location',
                                      value: next.formatLabel,
                                    ),
                                  ),
                              ],
                            ),
                            if (next != null &&
                                next.status == 'proposed' &&
                                !iAmProposer) ...[
                              const SizedBox(height: Insets.sm),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          _respondSession(next.id, 'decline'),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(0, 32),
                                      ),
                                      child: const Text('Decline'),
                                    ),
                                  ),
                                  const SizedBox(width: Insets.sm),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () =>
                                          _respondSession(next.id, 'accept'),
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(0, 32),
                                      ),
                                      child: const Text('Accept session'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (next == null && !requested) ...[
                              const SizedBox(height: Insets.sm),
                              OutlinedButton(
                                onPressed: () => _proposeSession(swap),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 32),
                                ),
                                child: const Text('Propose session'),
                              ),
                            ],
                          ],
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: Insets.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _LabeledValue(
                        label: 'You teach',
                        value: swap.myTeachSkill(myUserId).name,
                      ),
                    ),
                    Expanded(
                      child: _LabeledValue(
                        label: '${swap.otherUserName} teaches',
                        value: swap.myLearnSkill(myUserId).name,
                      ),
                    ),
                  ],
                ),
                if (!requested) ...[
                  const SizedBox(height: Insets.md),
                  if (iConfirmedFinish)
                    Text(
                      'Waiting for ${swap.otherUserName} to confirm finished',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  else if (otherConfirmedFinish)
                    Container(
                      padding: const EdgeInsets.all(Insets.md),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(Radii.sm),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${swap.otherUserName} marked this swap finished.',
                            style: text.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.offerFg,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Confirm if you agree — this completes the swap.',
                            style: text.bodySmall?.copyWith(
                              color: AppColors.offerFg,
                            ),
                          ),
                          const SizedBox(height: Insets.sm),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () => _act(
                                () => repo.confirmFinish(myUserId, swap.id),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.success,
                                minimumSize: const Size(0, 32),
                              ),
                              child: const Text('Confirm finished'),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (!_confirmingFinish)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _confirmingFinish = true),
                      icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 15,
                      ),
                      label: const Text('Mark finished'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: BorderSide(
                          color: AppColors.success.withValues(alpha: 0.4),
                        ),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Both you and ${swap.otherUserName} must mark this finished to complete it.',
                          style: text.bodySmall?.copyWith(
                            color: AppColors.offerFg,
                          ),
                        ),
                        const SizedBox(height: Insets.sm),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _act(
                                  () => repo.confirmFinish(myUserId, swap.id),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  minimumSize: const Size(0, 32),
                                ),
                                child: const Text('Confirm finished'),
                              ),
                            ),
                            const SizedBox(width: Insets.sm),
                            OutlinedButton(
                              onPressed: () =>
                                  setState(() => _confirmingFinish = false),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 32),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
                const SizedBox(height: Insets.sm),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: actions),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Small "..." menu carrying just the destructive End swap action — kept out
/// of the main button row since ending an active swap always needs a reason.
class _EndSwapMenu extends StatelessWidget {
  const _EndSwapMenu({required this.onSelected});
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 28,
      height: 28,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.more_vert_rounded,
          size: 16,
          color: scheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        onSelected: (_) => onSelected(),
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'end',
            child: Row(
              children: [
                Icon(
                  Icons.flag_outlined,
                  size: 15,
                  color: AppColors.destructive,
                ),
                SizedBox(width: 10),
                Text(
                  'End swap',
                  style: TextStyle(color: AppColors.destructive),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small caption label above a value line — used throughout the expanded
/// swap banner for a consistent, compact two-line stat layout.
class _LabeledValue extends StatelessWidget {
  const _LabeledValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        Text(
          value,
          style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ThreadError extends StatelessWidget {
  const _ThreadError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

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
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: Insets.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.isMine});
  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: isMine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMine ? AppColors.primary : scheme.surface,
            border: isMine ? null : Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(Radii.md),
              topRight: const Radius.circular(Radii.md),
              bottomLeft: Radius.circular(isMine ? Radii.md : Radii.xs),
              bottomRight: Radius.circular(isMine ? Radii.xs : Radii.md),
            ),
          ),
          child: Text(
            message.isDeleted ? 'Message deleted' : (message.body ?? ''),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isMine ? Colors.white : scheme.onSurface,
              fontStyle: message.isDeleted
                  ? FontStyle.italic
                  : FontStyle.normal,
              height: 1.35,
            ),
          ),
        ),
        // Timestamp sits outside the bubble, on the same side as it, like a
        // typical messaging app caption — not inside the colored container.
        Padding(
          padding: const EdgeInsets.only(
            top: 2,
            bottom: Insets.sm,
            left: 4,
            right: 4,
          ),
          child: Text(
            message.editedAt != null
                ? '${message.timeLabel} · edited'
                : message.timeLabel,
            style: TextStyle(
              fontSize: 10,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }
}

class _InputBar extends ConsumerWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.sending,
  });
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;

  void _onMediaTap(BuildContext context, WidgetRef ref) {
    final isPremium = ref.read(authControllerProvider).user?.isPremium ?? false;
    if (!isPremium) {
      showPaywallSheet(context);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Multimedia messaging is coming soon')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 4, Insets.lg, Insets.md),
      child: Row(
        // As the input grows with a longer message, keep the media/send
        // buttons pinned to the bottom instead of centering on the full height.
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Media button — Premium-locked, shows the paywall on tap for free tier.
          GestureDetector(
            onTap: () => _onMediaTap(context, ref),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.image_outlined,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.surface, width: 1),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 7,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: scheme.outlineVariant),
              ),
              padding: const EdgeInsets.only(left: 14, right: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    // Grows with the message like Discord's composer, up to
                    // ~3 lines — beyond that the field scrolls internally
                    // instead of pushing the input bar any taller.
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 84),
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: 'Message…',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: GestureDetector(
                      onTap: sending ? null : onSend,
                      child: Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: sending
                            ? const Padding(
                                padding: EdgeInsets.all(7),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakIceButton extends StatelessWidget {
  const _BreakIceButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.accent),
      label: const Text('Break the ice'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        foregroundColor: scheme.onSurfaceVariant,
        textStyle: Theme.of(context).textTheme.labelSmall,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
      ),
    );
  }
}

/// Vertical "..." menu in the thread header — Report / Block, mirroring the
/// same actions available from the Chat list's long-press sheet.
class _ThreadMenu extends ConsumerWidget {
  const _ThreadMenu({required this.otherUserId, required this.otherUserName});
  final String otherUserId;
  final String otherUserName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 32,
      height: 32,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.more_vert_rounded,
          size: 18,
          color: scheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        onSelected: (value) {
          if (value == 'report') _report(context, ref);
          if (value == 'block') _block(context, ref);
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'report',
            child: Row(
              children: [
                Icon(
                  Icons.flag_outlined,
                  size: 15,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Text('Report $otherUserName'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'block',
            child: Row(
              children: [
                Icon(
                  Icons.block_rounded,
                  size: 15,
                  color: AppColors.destructive,
                ),
                const SizedBox(width: 10),
                Text(
                  'Block $otherUserName',
                  style: const TextStyle(color: AppColors.destructive),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        title: Text('Report $otherUserName'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'What happened?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty || !context.mounted) return;
    try {
      await ref
          .read(safetyRepositoryProvider)
          .report(targetUserId: otherUserId, reason: reason);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$otherUserName has been reported')),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _block(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        title: Text('Block $otherUserName?'),
        content: const Text(
          'You won’t see each other in Discovery, and neither of you can message the other.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(safetyRepositoryProvider).block(otherUserId);
      ref.invalidate(conversationsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$otherUserName has been blocked')),
        );
        Navigator.pop(context); // leave the thread — nothing left to do here
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}
