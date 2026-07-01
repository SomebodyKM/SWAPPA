import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../../design_system/widgets/avatar.dart';
import 'conversation.dart';

class ChatThread extends StatefulWidget {
  const ChatThread({super.key, required this.conversation});
  final Conversation conversation;

  @override
  State<ChatThread> createState() => _ChatThreadState();
}

class _ChatThreadState extends State<ChatThread> {
  late final List<ChatMessage> _messages = [...widget.conversation.messages];
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  void _send() {
    final t = _controller.text.trim();
    if (t.isEmpty) return;
    setState(() => _messages.add(ChatMessage(fromMe: true, text: t, time: 'now')));
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
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
              padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.sm, Insets.lg, Insets.md),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
              ),
              child: Row(
                children: [
                  _circleBtn(context, Icons.arrow_back_rounded, () => Navigator.pop(context)),
                  const SizedBox(width: Insets.md),
                  Avatar(initials: c.initials, color: avatarColorFor(c.id), size: 36),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        Text('Active swap partner',
                            style: text.labelSmall?.copyWith(
                                color: AppColors.success, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  _BreakIceButton(onTap: () {}),
                ],
              ),
            ),
            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.md),
                itemCount: _messages.length,
                itemBuilder: (context, i) => _Bubble(message: _messages[i]),
              ),
            ),
            // Session proposal nudge
            const _ProposeNudge(),
            // Input
            _InputBar(controller: _controller, onSend: _send),
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final me = message.fromMe;
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: Insets.sm),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: me ? AppColors.primary : scheme.surface,
          border: me ? null : Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(Radii.md),
            topRight: const Radius.circular(Radii.md),
            bottomLeft: Radius.circular(me ? Radii.md : Radii.xs),
            bottomRight: Radius.circular(me ? Radii.xs : Radii.md),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: me ? Colors.white : scheme.onSurface,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              message.time,
              style: TextStyle(
                fontSize: 10,
                color: (me ? Colors.white : scheme.onSurfaceVariant).withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProposeNudge extends StatelessWidget {
  const _ProposeNudge();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const amberBg = Color(0xFFFFFBEB);
    const amberBorder = Color(0xFFFDE68A);
    const amberText = Color(0xFFB45309);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: amberBg,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: amberBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Propose a session',
                      style: text.labelMedium?.copyWith(color: amberText, fontWeight: FontWeight.w700)),
                  Text('Set a time and format',
                      style: text.bodySmall?.copyWith(color: amberText.withValues(alpha: 0.7))),
                ],
              ),
            ),
            FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.foreground,
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
              ),
              child: const Text('Propose'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 4, Insets.lg, Insets.md),
      child: Row(
        children: [
          // Media button (Premium-locked)
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.image_outlined, size: 16, color: scheme.onSurfaceVariant),
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
                  child: const Icon(Icons.lock_rounded, size: 7, color: Colors.white),
                ),
              ),
            ],
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
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onSubmitted: (_) => onSend(),
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
                  GestureDetector(
                    onTap: onSend,
                    child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.send_rounded, size: 14, color: Colors.white),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.pill)),
      ),
    );
  }
}
