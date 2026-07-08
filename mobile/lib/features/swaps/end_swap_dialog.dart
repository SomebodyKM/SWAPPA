import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';

/// Prompts for a reason before cancelling/declining a swap, matching the
/// backend rule in `swap.service.ts`: free only for the initiator backing
/// out of their own still-pending request — every other cancellation needs
/// one. When [reasonRequired] is true, an empty reason is treated the same
/// as backing out of the dialog (returns null) rather than sending it and
/// having the server reject it.
Future<String?> promptCancelSwap(
  BuildContext context, {
  required bool reasonRequired,
  String title = 'End this swap?',
  String body = 'This ends the swap for both of you. This cannot be undone.',
  String confirmLabel = 'End swap',
}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: reasonRequired
                  ? 'Reason (required, e.g. no-show)'
                  : 'Reason (optional)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Back'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.destructive,
            minimumSize: const Size(64, 40),
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  if (result == null) return null;
  if (reasonRequired && result.isEmpty) return null;
  return result;
}
