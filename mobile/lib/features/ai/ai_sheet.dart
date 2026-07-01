import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import 'sheet_scaffold.dart';

class AiActionDef {
  const AiActionDef(this.title, this.icon, this.cost, this.desc, this.result);
  final String title;
  final IconData icon;
  final int cost;
  final String desc;
  final String result;
}

const Map<String, AiActionDef> _aiDefs = {
  'icebreaker': AiActionDef(
    'AI Icebreaker', Icons.auto_awesome_rounded, 2,
    'Generate a warm, personalised opening message based on your shared skill interests.',
    "Hey Maya! I noticed you teach Mandarin and you want to learn guitar — what a perfect swap that would be! I've been playing for 3 years and genuinely love helping beginners find their rhythm. Would love to hear what drew you to Mandarin. Want to set up a first session? 🎸",
  ),
  'deep-rematch': AiActionDef(
    'Deep Re-Match', Icons.refresh_rounded, 3,
    'Broaden search criteria and re-rank your matches using AI to surface hidden gems.',
    'Found 3 new potential matches outside your usual radius:\n• Sofia T. — teaches Italian, wants Guitar (8 km)\n• Ravi K. — teaches Tabla, wants Photography (Remote)\n• Chen Wei — teaches Mandarin, wants Yoga (Remote)\n\nRanked by compatibility score.',
  ),
  'insight': AiActionDef(
    'Insight Report', Icons.trending_up_rounded, 5,
    'See demand for your skills in your area — who to target and how to stand out.',
    "Your skill 'Mandarin Chinese' is in high demand locally — 14 learners nearby with no teacher match yet. Adding a teaching style note could 2× your match rate.",
  ),
  'optimizer': AiActionDef(
    'Profile Optimizer', Icons.shield_rounded, 4,
    'AI reviews your profile and suggests edits to attract higher-quality swap partners.',
    'Suggested improvements:\n1. Add a teaching style to each skill tag\n2. Mention your availability (evenings, weekends)\n3. Upload a profile photo — 3× more messages\n4. Add a third "want to learn" skill',
  ),
};

Future<void> showAiSheet(BuildContext context, String action) {
  final def = _aiDefs[action] ?? _aiDefs['icebreaker']!;
  return showAppSheet(context, child: _AiSheet(def: def));
}

class _AiSheet extends StatefulWidget {
  const _AiSheet({required this.def});
  final AiActionDef def;

  @override
  State<_AiSheet> createState() => _AiSheetState();
}

class _AiSheetState extends State<_AiSheet> {
  String _step = 'preview'; // preview | loading | result
  late final TextEditingController _controller = TextEditingController();

  void _run() {
    setState(() => _step = 'loading');
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      _controller.text = widget.def.result;
      setState(() => _step = 'result');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      'loading' => _loading(context),
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
                    Icon(Icons.monetization_on_rounded, size: 11, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Text('${def.cost} credits',
                        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        Text(def.desc, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
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
                TextSpan(text: 'Never charged on failure. ', style: TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(text: 'Credits are only deducted after a result is delivered to you.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: Insets.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: _run, child: Text('Use ${def.cost} credits')),
        ),
        const SizedBox(height: Insets.sm),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: scheme.onSurfaceVariant)),
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
            child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
          ),
          const SizedBox(height: Insets.lg),
          Text('Generating…',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _result(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
            const SizedBox(width: 6),
            Text('Result ready', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${widget.def.cost} credits used',
                style: text.labelMedium?.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: Insets.md),
        TextField(
          controller: _controller,
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
                onPressed: () => Navigator.pop(context),
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
}
