import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_status_colors.dart';

/// Piccolo badge colorato che mostra lo stato di una richiesta.
/// Condiviso tra la vista del Dipendente e quella del Responsabile.
class RequestStatusChip extends StatelessWidget {
  final String status;

  const RequestStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Colori semantici dal tema: si adattano da soli a light/dark mode.
    final statusColors = theme.statusColors;

    late final String label;
    late final IconData icon;
    late final Color background;
    late final Color foreground;

    switch (status) {
      case LeaveStatus.approvata:
        label = 'Approvata';
        icon = Icons.check_circle_rounded;
        background = statusColors.successContainer;
        foreground = statusColors.onSuccessContainer;
      case LeaveStatus.rifiutata:
        label = 'Rifiutata';
        icon = Icons.cancel_rounded;
        background = statusColors.dangerContainer;
        foreground = statusColors.onDangerContainer;
      case LeaveStatus.annullata:
        label = 'Annullata';
        icon = Icons.block_rounded;
        background = scheme.surfaceContainerHighest;
        foreground = scheme.onSurfaceVariant;
      default: // in_attesa
        label = 'In attesa';
        icon = Icons.hourglass_top_rounded;
        background = statusColors.warningContainer;
        foreground = statusColors.onWarningContainer;
    }

    return Semantics(
      label: 'Stato richiesta: $label',
      child: Chip(
        avatar: Icon(icon, size: 18, color: foreground),
        label: Text(label, style: TextStyle(color: foreground)),
        backgroundColor: background,
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
