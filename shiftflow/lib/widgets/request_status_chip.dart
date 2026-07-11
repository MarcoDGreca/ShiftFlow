import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';

/// Piccolo badge colorato che mostra lo stato di una richiesta.
/// Condiviso tra la vista del Dipendente e quella del Responsabile.
class RequestStatusChip extends StatelessWidget {
  final String status;

  const RequestStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    late final String label;
    late final IconData icon;
    late final Color background;
    late final Color foreground;

    switch (status) {
      case LeaveStatus.approvata:
        label = 'Approvata';
        icon = Icons.check_circle;
        background = Colors.green.shade100;
        foreground = Colors.green.shade900;
      case LeaveStatus.rifiutata:
        label = 'Rifiutata';
        icon = Icons.cancel;
        background = Colors.red.shade100;
        foreground = Colors.red.shade900;
      case LeaveStatus.annullata:
        label = 'Annullata';
        icon = Icons.block;
        background = Colors.grey.shade300;
        foreground = Colors.grey.shade800;
      default: // in_attesa
        label = 'In attesa';
        icon = Icons.hourglass_top;
        background = scheme.secondaryContainer;
        foreground = scheme.onSecondaryContainer;
    }

    return Chip(
      avatar: Icon(icon, size: 18, color: foreground),
      label: Text(label, style: TextStyle(color: foreground)),
      backgroundColor: background,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
