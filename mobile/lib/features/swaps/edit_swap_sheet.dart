import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../../shared/models/skill.dart';
import '../auth/auth_controller.dart';
import '../profile/profile_providers.dart';
import 'swap_repository.dart';

/// Opens the "Edit swap terms" sheet — only ever shown to the initiator of a
/// still-`requested` swap (enforced server-side too). Returns true if saved.
Future<bool> showEditSwapSheet(
  BuildContext context,
  WidgetRef ref, {
  required SwapRecord swap,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditSwapSheet(swap: swap),
  );
  return saved ?? false;
}

class _EditSwapSheet extends ConsumerStatefulWidget {
  const _EditSwapSheet({required this.swap});
  final SwapRecord swap;

  @override
  ConsumerState<_EditSwapSheet> createState() => _EditSwapSheetState();
}

class _EditSwapSheetState extends ConsumerState<_EditSwapSheet> {
  late Skill? _offered = widget.swap.offeredSkill;
  late Skill? _requested = widget.swap.requestedSkill;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    final offered = _offered;
    final requested = _requested;
    if (offered == null || requested == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final myUserId = ref.read(authControllerProvider).user?.id ?? '';
    try {
      await ref
          .read(swapRepositoryProvider)
          .edit(
            myUserId,
            widget.swap.id,
            offeredSkillId: offered.id,
            requestedSkillId: requested.id,
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final myOffers = ref.watch(myTagsProvider);
    final theirOffers = ref.watch(userTagsProvider(widget.swap.otherUserId));
    final changed =
        _offered?.id != widget.swap.offeredSkill.id ||
        _requested?.id != widget.swap.requestedSkill.id;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
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
              Text('Edit swap terms', style: text.titleLarge),
              const SizedBox(height: 4),
              Text(
                'with ${widget.swap.otherUserName}',
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
                          'Couldn’t load ${widget.swap.otherUserName}’s skills',
                          style: text.bodySmall,
                        ),
                        data: (tags) {
                          final offers = tags.where((t) => t.isOffer).toList();
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
                  onPressed:
                      (_offered != null &&
                          _requested != null &&
                          changed &&
                          !_busy)
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
                      : const Text('Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
