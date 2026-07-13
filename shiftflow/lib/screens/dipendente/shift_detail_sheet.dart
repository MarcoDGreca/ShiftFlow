import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/shift.dart';
import '../../providers/shift_provider.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/initials_avatar.dart';

/// Mostra il dettaglio di un turno del Dipendente (UC2, passo 3): data, orario,
/// note e i colleghi in servizio nello stesso turno.
Future<void> showShiftDetailSheet(BuildContext context, Shift shift) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ShiftDetailSheet(shift: shift),
  );
}

class _ShiftDetailSheet extends StatefulWidget {
  final Shift shift;

  const _ShiftDetailSheet({required this.shift});

  @override
  State<_ShiftDetailSheet> createState() => _ShiftDetailSheetState();
}

class _ShiftDetailSheetState extends State<_ShiftDetailSheet> {
  /// I colleghi si leggono una sola volta all'apertura (lettura singola).
  late final Future<List<Shift>> _coworkers;

  @override
  void initState() {
    super.initState();
    _coworkers = context.read<ShiftProvider>().coworkersFor(widget.shift);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shift = widget.shift;
    // Lo staff serve per tradurre gli uid dei colleghi in nomi.
    final staffProvider = context.watch<StaffProvider>();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dettaglio turno', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(
            icon: Icons.calendar_today_rounded,
            text: DateFormatter.full(shift.date),
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            icon: Icons.schedule_rounded,
            text: DateFormatter.timeRange(shift.startTime, shift.endTime),
          ),
          if (shift.notes != null && shift.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(icon: Icons.notes_rounded, text: shift.notes!),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('Colleghi in servizio', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          FutureBuilder<List<Shift>>(
            future: _coworkers,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Center(
                    child: SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final coworkers = snapshot.data ?? const <Shift>[];
              if (coworkers.isEmpty) {
                return Text(
                  'Nessun collega in questo turno.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }
              return Column(
                children: [
                  for (final c in coworkers)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: InitialsAvatar(
                        name: staffProvider.byUid(c.employeeUid)?.name,
                      ),
                      title: Text(
                        staffProvider.byUid(c.employeeUid)?.name ?? 'Collega',
                      ),
                      subtitle: Text(
                        DateFormatter.timeRange(c.startTime, c.endTime),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Riga "icona + testo" del dettaglio.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
      ],
    );
  }
}
