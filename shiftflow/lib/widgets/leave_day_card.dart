import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import '../core/theme/app_status_colors.dart';
import '../core/utils/date_formatter.dart';
import '../models/leave_request.dart';
import 'glass_container.dart';

/// Card compatta di un'assenza (ferie/permesso) **approvata**, mostrata nel
/// dettaglio del giorno selezionato sui calendari.
///
/// [employeeName] si passa solo nella vista del Responsabile (che vede le
/// assenze di tutti); nella vista del Dipendente resta `null`.
class LeaveDayCard extends StatelessWidget {
  final LeaveRequest request;
  final String? employeeName;

  const LeaveDayCard({super.key, required this.request, this.employeeName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColors = theme.statusColors;

    final isFerie = request.isFerie;
    final accent = isFerie ? statusColors.info : statusColors.warning;
    final icon = isFerie
        ? Icons.beach_access_rounded
        : Icons.more_time_rounded;
    final title = isFerie ? 'Ferie' : 'Permesso';
    final reason = request.reason?.trim();

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.15),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _period(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                if (employeeName != null) ...[
                  const SizedBox(height: 2),
                  _line(theme, Icons.person_outline_rounded, employeeName!),
                ],
                if (reason != null && reason.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  _line(theme, Icons.notes_rounded, reason),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Testo del periodo: intervallo per le ferie, orario (o "Tutto il giorno")
  /// per il permesso.
  String _period() {
    if (request.isFerie) {
      final start = request.startDate;
      final end = request.endDate;
      if (start == null || end == null) return '';
      if (DateFormatter.toDayLabel(start) == DateFormatter.toDayLabel(end)) {
        return DateFormatter.dayMonthShort(start);
      }
      return 'dal ${DateFormatter.dayMonthShort(start)} '
          'al ${DateFormatter.dayMonthShort(end)}';
    }
    // Permesso.
    if (request.startTime != null && request.endTime != null) {
      return '${request.startTime}–${request.endTime}';
    }
    return 'tutto il giorno';
  }

  Widget _line(ThemeData theme, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
