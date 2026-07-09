import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../auth/auth_controller.dart';
import '../discovery/match.dart';
import '../discovery/widgets/match_card.dart';
import '../profile/profile_providers.dart';
import 'ai_repository.dart';
import 'buy_boost_sheet.dart';
import 'sheet_scaffold.dart';

class _AiActionDef {
  const _AiActionDef(this.title, this.icon, this.cost, this.desc);
  final String title;
  final IconData icon;
  final int cost;
  final String desc;
}

const Map<String, _AiActionDef> _aiDefs = {
  'icebreaker': _AiActionDef(
    'AI Icebreaker',
    Icons.auto_awesome_rounded,
    AiCosts.icebreaker,
    'Generate a warm, personalised opening message based on your shared skill interests.',
  ),
  'deep-rematch': _AiActionDef(
    'Deep Re-Match',
    Icons.refresh_rounded,
    AiCosts.rematch,
    'Broaden search criteria and re-rank your matches using AI to surface hidden gems.',
  ),
  'insight': _AiActionDef(
    'Insight Report',
    Icons.trending_up_rounded,
    AiCosts.insight,
    'See demand for your skills — who to target and how to stand out.',
  ),
  'optimizer': _AiActionDef(
    'Profile Optimizer',
    Icons.shield_rounded,
    AiCosts.profileOptimizer,
    'AI reviews your profile and suggests a rewritten bio to attract higher-quality swap partners.',
  ),
};

/// Opens the AI action sheet. [matchUserId] is required for 'icebreaker'.
/// Returns the generated message text if the caller taps "Use this" on an
/// icebreaker result — every other action applies its own result (or is
/// purely informational) and always resolves to null.
Future<String?> showAiSheet(
  BuildContext context,
  String action, {
  String? matchUserId,
}) {
  final def = _aiDefs[action] ?? _aiDefs['icebreaker']!;
  return showAppSheet<String>(
    context,
    child: _AiSheet(action: action, def: def, matchUserId: matchUserId),
  );
}

class _AiSheet extends ConsumerStatefulWidget {
  const _AiSheet({required this.action, required this.def, this.matchUserId});
  final String action;
  final _AiActionDef def;
  final String? matchUserId;

  @override
  ConsumerState<_AiSheet> createState() => _AiSheetState();
}

class _AiSheetState extends ConsumerState<_AiSheet> {
  String _step = 'preview'; // preview | loading | error
  String? _error;

  // Populated by whichever action actually ran — only one of these is ever
  // non-null at a time.
  String? _icebreakerText;
  InsightReport? _insight;
  List<MatchResult>? _rematchResults;
  ProfileOptimizerResult? _optimizer;

  Future<void> _run() async {
    setState(() {
      _step = 'loading';
      _error = null;
    });
    final repo = ref.read(aiRepositoryProvider);
    try {
      switch (widget.action) {
        case 'icebreaker':
          _icebreakerText = await repo.icebreaker(widget.matchUserId!);
        case 'deep-rematch':
          _rematchResults = await repo.rematch();
        case 'insight':
          _insight = await repo.insight();
        case 'optimizer':
          _optimizer = await repo.profileOptimizer();
      }
      if (mounted) setState(() => _step = 'result');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 402) {
        Navigator.pop(context);
        showBuyBoostSheet(context);
        return;
      }
      setState(() {
        _step = 'error';
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      'loading' => _loading(context),
      'error' => _errorView(context),
      'result' => _result(context),
      _ => _preview(context),
    };
  }

  Widget _preview(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final def = widget.def;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Icon(def.icon, size: 22, color: Colors.white),
            ),
            const SizedBox(width: Insets.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.title, style: text.titleLarge),
                Row(
                  children: [
                    Icon(
                      Icons.monetization_on_rounded,
                      size: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${def.cost} credits',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        Text(
          def.desc,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: Insets.md),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: RichText(
            text: TextSpan(
              style: text.bodySmall?.copyWith(color: const Color(0xFFB45309)),
              children: const [
                TextSpan(
                  text: 'Never charged on failure. ',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text:
                      'Credits are only deducted after a result is delivered to you.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Insets.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _run,
            child: Text('Use ${def.cost} credits'),
          ),
        ),
        const SizedBox(height: Insets.sm),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }

  Widget _loading(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: Insets.lg),
          Text(
            'Generating…',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _errorView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 40,
          color: AppColors.destructive,
        ),
        const SizedBox(height: Insets.md),
        Text(
          _error ?? 'Something went wrong',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: Insets.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: _run, child: const Text('Try again')),
        ),
        const SizedBox(height: Insets.sm),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }

  Widget _resultHeader(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          size: 16,
          color: AppColors.success,
        ),
        const SizedBox(width: 6),
        Text(
          'Result ready',
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        Text(
          '${widget.def.cost} credits used',
          style: text.labelMedium?.copyWith(
            color: AppColors.success,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _result(BuildContext context) {
    return switch (widget.action) {
      'icebreaker' => _icebreakerResult(context),
      'deep-rematch' => _rematchResult(context),
      'insight' => _insightResult(context),
      'optimizer' => _optimizerResult(context),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _icebreakerResult(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: _icebreakerText);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _resultHeader(context),
        const SizedBox(height: Insets.md),
        TextField(
          controller: controller,
          maxLines: 6,
          decoration: InputDecoration(
            filled: true,
            fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.md),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: Insets.lg),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('Use this'),
              ),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Discard'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _rematchResult(BuildContext context) {
    final results = _rematchResults ?? const [];
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _resultHeader(context),
        const SizedBox(height: Insets.md),
        if (results.isEmpty)
          Text(
            'No additional matches found right now — try again later as more people join.',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          )
        else
          for (final m in results) ...[
            MatchCard(match: m),
            const SizedBox(height: Insets.md),
          ],
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  Widget _insightResult(BuildContext context) {
    final report = _insight;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _resultHeader(context),
        const SizedBox(height: Insets.md),
        Text(
          report?.summary ?? '',
          style: text.bodyMedium?.copyWith(height: 1.4),
        ),
        if (report != null && report.demand.isNotEmpty) ...[
          const SizedBox(height: Insets.lg),
          Text('Demand for your skills', style: text.labelMedium),
          const SizedBox(height: Insets.sm),
          for (final d in report.demand)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      d.skill,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${d.wanters} ${d.wanters == 1 ? 'learner' : 'learners'}',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: Insets.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  Widget _optimizerResult(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final result = _optimizer;
    final controller = TextEditingController(text: result?.suggestedBio);
    return StatefulBuilder(
      builder: (context, setLocalState) {
        var applying = false;
        Future<void> apply() async {
          setLocalState(() => applying = true);
          try {
            await ref
                .read(profileRepositoryProvider)
                .updateProfile(bio: controller.text);
            await ref.read(authControllerProvider.notifier).refreshUser();
            if (context.mounted) Navigator.pop(context);
          } on ApiException catch (e) {
            setLocalState(() => applying = false);
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(e.message)));
            }
          }
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _resultHeader(context),
            const SizedBox(height: Insets.md),
            Text('Suggested bio', style: text.labelMedium),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.md),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (result != null && result.suggestedTags.isNotEmpty) ...[
              const SizedBox(height: Insets.lg),
              Text('Your standout skills', style: text.labelMedium),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in result.suggestedTags)
                    Chip(
                      label: Text(t),
                      backgroundColor: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.6),
                      side: BorderSide.none,
                    ),
                ],
              ),
            ],
            const SizedBox(height: Insets.lg),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: applying ? null : apply,
                    child: applying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Apply to profile'),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: applying ? null : () => Navigator.pop(context),
                    child: const Text('Discard'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
