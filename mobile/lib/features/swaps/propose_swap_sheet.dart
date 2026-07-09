import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../../shared/models/skill.dart';
import '../auth/auth_controller.dart';
import '../profile/profile_providers.dart';
import 'swap_repository.dart';

/// Opens the "Propose a swap" sheet for [partnerId]/[partnerName] — used from
/// a chat thread. Returns true if a swap was created.
Future<bool> showProposeSwapSheet(
  BuildContext context,
  WidgetRef ref, {
  required String partnerId,
  required String partnerName,
}) async {
  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _ProposeSwapSheet(partnerId: partnerId, partnerName: partnerName),
  );
  return created ?? false;
}

class _ProposeSwapSheet extends ConsumerStatefulWidget {
  const _ProposeSwapSheet({required this.partnerId, required this.partnerName});
  final String partnerId;
  final String partnerName;

  @override
  ConsumerState<_ProposeSwapSheet> createState() => _ProposeSwapSheetState();
}

class _ProposeSwapSheetState extends ConsumerState<_ProposeSwapSheet> {
  Skill? _offered; // what I teach
  Skill? _requested; // what I want from them

  // First session — optional; left blank, only the swap itself is created.
  DateTime? _date;
  TimeOfDay? _time;
  String _format = 'remote';
  bool _iTeach = true;

  bool _busy = false;
  String? _error;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    final offered = _offered;
    final requested = _requested;
    if (offered == null || requested == null || _busy) return;

    DateTime? scheduledAt;
    if (_date != null && _time != null) {
      scheduledAt = DateTime(
        _date!.year,
        _date!.month,
        _date!.day,
        _time!.hour,
        _time!.minute,
      );
      if (scheduledAt.isBefore(DateTime.now())) {
        setState(() => _error = 'Pick a session time in the future');
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final myUserId = ref.read(authControllerProvider).user?.id ?? '';
    try {
      final swap = await ref
          .read(swapRepositoryProvider)
          .create(
            myUserId: myUserId,
            partnerId: widget.partnerId,
            offeredSkillId: offered.id,
            requestedSkillId: requested.id,
          );
      if (scheduledAt != null) {
        try {
          await ref
              .read(swapRepositoryProvider)
              .proposeSession(
                swapId: swap.id,
                teacherId: _iTeach ? myUserId : widget.partnerId,
                learnerId: _iTeach ? widget.partnerId : myUserId,
                scheduledAt: scheduledAt,
                format: _format,
              );
        } on ApiException catch (e) {
          // The swap itself is already created — surface this as a partial
          // failure rather than losing that success.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Swap sent, but the session couldn’t be scheduled: ${e.message}',
                ),
              ),
            );
          }
        }
      }
      ref.invalidate(openSwapWithPartnerProvider(widget.partnerId));
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() {
        _error = e.isLimitReached
            ? 'You’ve reached your active swap limit. Finish or cancel one first.'
            : e.message;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final myOffers = ref.watch(myTagsProvider);
    final theirOffers = ref.watch(userTagsProvider(widget.partnerId));

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.xl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.lg,
            Insets.md,
            Insets.lg,
            Insets.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                ),
              ),
              const SizedBox(height: Insets.md),
              Text('Propose a swap', style: text.titleLarge),
              const SizedBox(height: 4),
              Text(
                'with ${widget.partnerName}',
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Insets.lg),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What you’ll teach', style: text.labelMedium),
                      const SizedBox(height: 6),
                      myOffers.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: CircularProgressIndicator(),
                        ),
                        error: (e, _) => Text(
                          'Couldn’t load your skills',
                          style: text.bodySmall,
                        ),
                        data: (tags) {
                          final offers = tags.where((t) => t.isOffer).toList();
                          if (offers.isEmpty) {
                            return Text(
                              'Add a skill you can teach in your profile first',
                              style: text.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            );
                          }
                          return Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final t in offers)
                                ChoiceChip(
                                  label: Text(t.skill.name),
                                  selected: _offered?.id == t.skill.id,
                                  onSelected: (_) =>
                                      setState(() => _offered = t.skill),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: Insets.lg),
                      Text('What you’ll learn', style: text.labelMedium),
                      const SizedBox(height: 6),
                      theirOffers.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: CircularProgressIndicator(),
                        ),
                        error: (e, _) => Text(
                          'Couldn’t load ${widget.partnerName}’s skills',
                          style: text.bodySmall,
                        ),
                        data: (tags) {
                          final offers = tags.where((t) => t.isOffer).toList();
                          if (offers.isEmpty) {
                            return Text(
                              '${widget.partnerName} hasn’t listed anything to teach yet',
                              style: text.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            );
                          }
                          return Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final t in offers)
                                ChoiceChip(
                                  label: Text(t.skill.name),
                                  selected: _requested?.id == t.skill.id,
                                  onSelected: (_) =>
                                      setState(() => _requested = t.skill),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: Insets.lg),
                      Container(height: 1, color: scheme.outlineVariant),
                      const SizedBox(height: Insets.lg),
                      Text('First session', style: text.labelMedium),
                      const SizedBox(height: 2),
                      Text(
                        'Optional — leave blank to schedule this later.',
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Insets.sm),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(
                                Icons.calendar_today_rounded,
                                size: 15,
                              ),
                              label: Text(
                                _date == null
                                    ? 'Date'
                                    : '${_date!.day}/${_date!.month}/${_date!.year}',
                              ),
                            ),
                          ),
                          const SizedBox(width: Insets.sm),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickTime,
                              icon: const Icon(
                                Icons.schedule_rounded,
                                size: 15,
                              ),
                              label: Text(
                                _time == null ? 'Time' : _time!.format(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Insets.md),
                      Text('Format', style: text.labelMedium),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: [
                          ChoiceChip(
                            label: const Text('Remote'),
                            selected: _format == 'remote',
                            onSelected: (_) =>
                                setState(() => _format = 'remote'),
                          ),
                          ChoiceChip(
                            label: const Text('In-person'),
                            selected: _format == 'in_person',
                            onSelected: (_) =>
                                setState(() => _format = 'in_person'),
                          ),
                        ],
                      ),
                      const SizedBox(height: Insets.md),
                      Text('For this session', style: text.labelMedium),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: [
                          ChoiceChip(
                            label: const Text('I’ll teach'),
                            selected: _iTeach,
                            onSelected: (_) => setState(() => _iTeach = true),
                          ),
                          ChoiceChip(
                            label: const Text('I’ll learn'),
                            selected: !_iTeach,
                            onSelected: (_) => setState(() => _iTeach = false),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: Insets.md),
                        Text(
                          _error!,
                          style: text.bodySmall?.copyWith(
                            color: AppColors.destructive,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Insets.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_offered != null && _requested != null && !_busy)
                      ? _submit
                      : null,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Send swap request'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
