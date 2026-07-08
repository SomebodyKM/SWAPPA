import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';

/// What the "Propose a session" sheet collected.
class SessionProposal {
  const SessionProposal({
    required this.scheduledAt,
    required this.format,
    required this.iTeach,
  });
  final DateTime scheduledAt;
  final String format; // in_person | remote
  final bool iTeach; // false = I'm the learner for this particular session
}

/// Opens the "Propose a session" sheet for an active swap with [partnerName].
/// Returns `null` if the user backed out.
Future<SessionProposal?> showProposeSessionSheet(
  BuildContext context, {
  required String partnerName,
}) {
  return showModalBottomSheet<SessionProposal>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProposeSessionSheet(partnerName: partnerName),
  );
}

class _ProposeSessionSheet extends StatefulWidget {
  const _ProposeSessionSheet({required this.partnerName});
  final String partnerName;

  @override
  State<_ProposeSessionSheet> createState() => _ProposeSessionSheetState();
}

class _ProposeSessionSheetState extends State<_ProposeSessionSheet> {
  DateTime? _date;
  TimeOfDay? _time;
  String _format = 'remote';
  bool _iTeach = true;
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

  void _submit() {
    final date = _date;
    final time = _time;
    if (date == null || time == null) return;
    final scheduledAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (scheduledAt.isBefore(DateTime.now())) {
      setState(() => _error = 'Pick a time in the future');
      return;
    }
    Navigator.pop(
      context,
      SessionProposal(
        scheduledAt: scheduledAt,
        format: _format,
        iTeach: _iTeach,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final ready = _date != null && _time != null;

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
            Insets.md,
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
              Text('Propose a session', style: text.titleLarge),
              const SizedBox(height: 4),
              Text(
                'with ${widget.partnerName}',
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Insets.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_rounded, size: 15),
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
                      icon: const Icon(Icons.schedule_rounded, size: 15),
                      label: Text(
                        _time == null ? 'Time' : _time!.format(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.lg),
              Text('Format', style: text.labelMedium),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('Remote'),
                    selected: _format == 'remote',
                    onSelected: (_) => setState(() => _format = 'remote'),
                  ),
                  ChoiceChip(
                    label: const Text('In-person'),
                    selected: _format == 'in_person',
                    onSelected: (_) => setState(() => _format = 'in_person'),
                  ),
                ],
              ),
              const SizedBox(height: Insets.lg),
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
                  style: text.bodySmall?.copyWith(color: AppColors.destructive),
                ),
              ],
              const SizedBox(height: Insets.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: ready ? _submit : null,
                  child: const Text('Propose session'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
