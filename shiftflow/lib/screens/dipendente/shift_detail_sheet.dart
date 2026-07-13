import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/shift.dart';
import '../../providers/shift_provider.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/date_badge.dart';
import '../../widgets/info_pill.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/section_header.dart';

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

    final duration = DateFormatter.durationLabel(
      shift.startTime,
      shift.endTime,
    );
    final overnight = DateFormatter.isOvernight(
      shift.startTime,
      shift.endTime,
    );

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
          // Intestazione col badge data e l'orario in grande: le due
          // informazioni chiave del turno si leggono senza scorrere.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DateBadge(date: shift.date),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormatter.timeRange(shift.startTime, shift.endTime),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (duration != null)
                          InfoPill(
                            icon: Icons.timelapse_rounded,
                            label: duration,
                          ),
                        if (overnight)
                          const InfoPill(
                            icon: Icons.nightlight_round,
                            label: 'Finisce il giorno dopo',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            DateFormatter.full(shift.date),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (shift.notes != null && shift.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(icon: Icons.notes_rounded, text: shift.notes!),
          ],
          const SectionHeader(
            title: 'Colleghi in servizio',
            padding: EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.sm),
          ),
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
