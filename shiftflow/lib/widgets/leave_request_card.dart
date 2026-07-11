import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/date_formatter.dart';
import '../models/leave_request.dart';
import '../models/shift.dart';
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

  bool get _isCambio => request.type == LeaveType.cambioTurno;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reason = request.reason?.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_isCambio ? Icons.swap_horiz : Icons.beach_access,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isCambio ? 'Cambio turno' : 'Permesso',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                RequestStatusChip(status: request.status),
              ],
            ),
            const SizedBox(height: 4),
            if (employeeName != null)
              _InfoLine(icon: Icons.person_outline, text: employeeName!),
            if (relatedShift != null)
              _InfoLine(
                icon: Icons.event,
                text: 'Turno: ${DateFormatter.full(relatedShift!.date)} · '
                    '${relatedShift!.startTime}–${relatedShift!.endTime}',
              ),
            if (reason != null && reason.isNotEmpty)
              _InfoLine(icon: Icons.notes_outlined, text: reason),
            if (request.createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Inviata il ${DateFormatter.toDayLabel(request.createdAt!)}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            if (actions != null) ...[
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: actions),
            ],
          ],
        ),
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
