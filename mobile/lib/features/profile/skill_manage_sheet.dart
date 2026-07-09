import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../../shared/models/skill.dart';
import 'profile_providers.dart';

/// Manage a single skill tag — change proficiency (for skills you teach), add
/// the complementary kind (also teach / also learn), or remove it.
Future<void> showSkillManageSheet(BuildContext context, SkillTag tag) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SkillManageSheet(tag: tag),
  );
}

class _SkillManageSheet extends ConsumerStatefulWidget {
  const _SkillManageSheet({required this.tag});
  final SkillTag tag;

  @override
  ConsumerState<_SkillManageSheet> createState() => _SkillManageSheetState();
}

class _SkillManageSheetState extends ConsumerState<_SkillManageSheet> {
  static const _profs = ['beginner', 'intermediate', 'advanced', 'expert'];
  late String _proficiency = widget.tag.proficiency ?? 'intermediate';
  bool _busy = false;
  String? _error;

  ProfileRepository get _repo => ref.read(profileRepositoryProvider);

  Future<void> _run(Future<void> Function() action, {bool close = true}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(myTagsProvider);
      if (mounted && close) Navigator.pop(context);
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
    final tag = widget.tag;
    final isOffer = tag.isOffer;

    return Container(
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
            Insets.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: Insets.lg),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (isOffer
                          ? AppColors.offerBg
                          : AppColors.primary.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Icon(
                      isOffer
                          ? Icons.school_rounded
                          : Icons.auto_stories_rounded,
                      size: 20,
                      color: isOffer ? AppColors.offerFg : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tag.skill.name, style: text.titleMedium),
                        Text(
                          isOffer
                              ? 'You can teach this'
                              : 'You want to learn this',
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Proficiency — for both teach (skill level) and learn (current level).
              const SizedBox(height: Insets.lg),
              Text(
                isOffer ? 'Your proficiency' : 'Your current level',
                style: text.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (final p in _profs)
                    ChoiceChip(
                      label: Text(p[0].toUpperCase() + p.substring(1)),
                      selected: _proficiency == p,
                      onSelected: _busy
                          ? null
                          : (_) {
                              setState(() => _proficiency = p);
                              _run(
                                () => _repo.updateTagProficiency(tag.id, p),
                                close: false,
                              );
                            },
                    ),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: Insets.sm),
                Text(
                  _error!,
                  style: text.bodySmall?.copyWith(color: AppColors.destructive),
                ),
              ],

              const SizedBox(height: Insets.lg),

              // Complementary kind
              _ActionTile(
                icon: isOffer
                    ? Icons.auto_stories_rounded
                    : Icons.school_rounded,
                label: isOffer
                    ? 'Also want to learn this'
                    : 'Also offer to teach this',
                onTap: _busy
                    ? null
                    : () => _run(() async {
                        try {
                          await _repo.addTag(
                            skillId: tag.skill.id,
                            kind: isOffer ? 'want' : 'offer',
                            proficiency: isOffer ? null : 'intermediate',
                          );
                        } on ApiException catch (e) {
                          if (e.code == 'TAG_EXISTS') return; // already have it
                          rethrow;
                        }
                      }),
              ),
              _ActionTile(
                icon: Icons.delete_outline_rounded,
                label: isOffer
                    ? 'Remove from teaching'
                    : 'Remove from learning',
                danger: true,
                onTap: _busy ? null : () => _run(() => _repo.removeTag(tag.id)),
              ),

              const SizedBox(height: Insets.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = danger ? AppColors.destructive : scheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: Insets.md),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
