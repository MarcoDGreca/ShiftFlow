import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import '../core/utils/date_formatter.dart';
import '../models/leave_request.dart';
import '../models/shift.dart';
import 'glass_container.dart';
import 'request_status_chip.dart';

/// Card che mostra una richiesta di permesso/cambio turno.
///
/// È usata sia dal Dipendente (le proprie richieste) sia dal Responsabile
/// (tutte le richieste). Le differenze si passano via parametri:
///  - [employeeName]: il nome di chi ha inviato (solo il Responsabile lo mostra);
///  - [relatedShift]: il turno collegato, se disponibile;
///  - [actions]: i pulsanti Approva/Rifiuta (solo il Responsabile, e solo se
///    la richiesta è in attesa).
class LeaveRequestCard extends StatelessWidget {
  final LeaveRequest request;
  final String? employeeName;
  final Shift? relatedShift;
  final Widget? actions;

  const LeaveRequestCard({
    super.key,
    required this.request,
    this.employeeName,
    this.relatedShift,
    this.actions,
  });

  /// Testo del periodo dell'assenza (per ferie/permesso): intervallo di giorni,
  /// oppure il giorno + orario del permesso. `null` per il cambio turno (che è
  /// descritto dal turno collegato) o per le vecchie richieste senza date.
  String? _period() {
    if (request.isFerie) {
      final s = request.startDate, e = request.endDate;
      if (s == null || e == null) return null;
      if (DateFormatter.toDayLabel(s) == DateFormatter.toDayLabel(e)) {
        return DateFormatter.full(s);
      }
      return 'Dal ${DateFormatter.full(s)} al ${DateFormatter.full(e)}';
    }
    if (request.isPermesso) {
      final s = request.startDate;
      if (s == null) return null;
      final day = DateFormatter.full(s);
      if (request.startTime != null && request.endTime != null) {
        return '$day · ${request.startTime}–${request.endTime}';
      }
      return '$day · tutto il giorno';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reason = request.reason?.trim();

    final IconData typeIcon = request.isCambioTurno
        ? Icons.swap_horiz_rounded
        : request.isFerie
        ? Icons.beach_access_rounded
        : Icons.more_time_rounded;
    final String typeLabel = request.isCambioTurno
        ? 'Cambio turno'
        : request.isFerie
        ? 'Ferie'
        : 'Permesso';
    final period = _period();

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(typeIcon, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(typeLabel, style: theme.textTheme.titleMedium),
              ),
              RequestStatusChip(status: request.status),
            ],
          ),
          const SizedBox(height: 4),
          if (employeeName != null)
            _InfoLine(icon: Icons.person_outline_rounded, text: employeeName!),
          if (period != null)
            _InfoLine(icon: Icons.event_rounded, text: period),
          if (relatedShift != null)
            _InfoLine(
              icon: Icons.event_rounded,
              text:
                  'Turno: ${DateFormatter.full(relatedShift!.date)} · '
                  '${DateFormatter.timeRange(relatedShift!.startTime, relatedShift!.endTime)}',
            ),
          if (reason != null && reason.isNotEmpty)
            _InfoLine(icon: Icons.notes_rounded, text: reason),
          if (request.createdAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Inviata il ${DateFormatter.toDayLabel(request.createdAt!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (actions != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(alignment: Alignment.centerRight, child: actions),
          ],
        ],
      ),
    );
  }
}

/// Riga "icona + testo" usata nel corpo della card.
class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
