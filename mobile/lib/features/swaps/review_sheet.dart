import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../../design_system/widgets/sub_page.dart';
import '../profile/models/review.dart';
import '../profile/profile_providers.dart';

/// Opens the leave/edit-review sheet for a completed swap. [existing] is the
/// caller's own prior review, if any (pre-fills the form and switches the
/// copy to "Update review" + adds a delete option). Returns true if the
/// review was created, edited, or deleted, so the caller can refresh.
Future<bool> showReviewSheet(
  BuildContext context, {
  required String swapId,
  required String otherUserName,
  MyReview? existing,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReviewSheet(
      swapId: swapId,
      otherUserName: otherUserName,
      existing: existing,
    ),
  );
  return result ?? false;
}

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({
    required this.swapId,
    required this.otherUserName,
    this.existing,
  });

  final String swapId;
  final String otherUserName;
  final MyReview? existing;

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  late int _rating = widget.existing?.rating ?? 0;
  late final _comment = TextEditingController(text: widget.existing?.comment);
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  Future<void> _submit() async {
    if (_rating == 0 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(profileRepositoryProvider);
    final comment = _comment.text.trim();
    try {
      if (_isEdit) {
        await repo.editReview(
          widget.existing!.id,
          rating: _rating,
          comment: comment.isEmpty ? null : comment,
        );
      } else {
        await repo.createReview(
          widget.swapId,
          rating: _rating,
          comment: comment.isEmpty ? null : comment,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_busy || widget.existing == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .deleteReview(widget.existing!.id);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
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
          padding: EdgeInsets.fromLTRB(
            Insets.lg,
            Insets.md,
            Insets.lg,
            Insets.lg + MediaQuery.of(context).viewInsets.bottom,
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
              const SizedBox(height: Insets.md),
              Text(
                _isEdit ? 'Update your review' : 'Leave a review',
                style: text.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'How was swapping with ${widget.otherUserName}?',
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Insets.lg),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      GestureDetector(
                        onTap: () => setState(() => _rating = i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            i <= _rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 36,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.lg),
              Text('Comment (optional)', style: text.labelMedium),
              const SizedBox(height: 6),
              FilledField(
                controller: _comment,
                hint: 'Share how it went…',
                maxLines: 4,
              ),
              if (_error != null) ...[
                const SizedBox(height: Insets.md),
                Text(
                  _error!,
                  style: text.bodySmall?.copyWith(color: AppColors.destructive),
                ),
              ],
              const SizedBox(height: Insets.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_rating > 0 && !_busy) ? _submit : null,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isEdit ? 'Update review' : 'Post review'),
                ),
              ),
              if (_isEdit) ...[
                const SizedBox(height: Insets.sm),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _busy ? null : _delete,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.destructive,
                    ),
                    child: const Text('Delete review'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
