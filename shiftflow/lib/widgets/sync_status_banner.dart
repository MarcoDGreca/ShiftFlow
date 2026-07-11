import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import '../core/theme/app_status_colors.dart';

/// Striscia informativa sullo stato di sincronizzazione dei dati (RNF4 / §7.1).
///
/// Non è un errore: comunica solo che si sta lavorando offline o che ci sono
/// modifiche in coda. Se tutto è sincronizzato non occupa spazio.
class SyncStatusBanner extends StatelessWidget {
  final bool isFromCache;
  final bool hasPendingWrites;

  const SyncStatusBanner({
    super.key,
    required this.isFromCache,
    required this.hasPendingWrites,
  });

  @override
  Widget build(BuildContext context) {
    if (!isFromCache && !hasPendingWrites) return const SizedBox.shrink();

    final statusColors = Theme.of(context).statusColors;

    // Le scritture in coda sono l'informazione più importante da dare:
    // usano il colore "attenzione"; l'offline è solo informativo.
    final (icon, text, background, foreground) = hasPendingWrites
        ? (
            Icons.sync_problem_rounded,
            'Modifiche non ancora sincronizzate',
            statusColors.warningContainer,
            statusColors.onWarningContainer,
          )
        : (
            Icons.cloud_off_rounded,
            'Offline · dati dalla memoria locale',
            statusColors.infoContainer,
            statusColors.onInfoContainer,
          );

    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: TextStyle(color: foreground)),
          ),
        ],
      ),
    );
  }
}
