import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import '../core/theme/app_status_colors.dart';
import '../core/utils/date_formatter.dart';

/// Striscia informativa sullo stato di sincronizzazione dei dati (RNF2 / §7.1).
///
/// Di norma non è un errore: comunica che si sta lavorando offline o che ci
/// sono modifiche in coda. Ma se il caricamento è FALLITO ([errorMessage]) lo
/// dice chiaramente, con priorità: un errore non deve travestirsi da "offline"
/// (che farebbe pensare a un semplice calo di rete). Se tutto è sincronizzato
/// e non c'è errore, non occupa spazio.
class SyncStatusBanner extends StatelessWidget {
  final bool isFromCache;
  final bool hasPendingWrites;

  /// Quando i dati sono stati sincronizzati col server l'ultima volta: mostrata
  /// quando si è offline, così l'utente sa quanto sono aggiornati (UC2-E1).
  final DateTime? lastUpdated;

  /// Messaggio d'errore del caricamento (es. permessi negati). Se presente,
  /// prevale su offline/modifiche-in-coda: i dati mostrati sotto potrebbero
  /// essere vecchi e l'utente deve saperlo.
  final String? errorMessage;

  const SyncStatusBanner({
    super.key,
    required this.isFromCache,
    required this.hasPendingWrites,
    this.lastUpdated,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (errorMessage == null && !isFromCache && !hasPendingWrites) {
      return const SizedBox.shrink();
    }

    final statusColors = Theme.of(context).statusColors;

    // Priorità: errore (rosso) → modifiche in coda (attenzione) → offline (info).
    // L'errore è lo stato più importante: qualcosa non ha funzionato davvero.
    final (icon, text, background, foreground) = errorMessage != null
        ? (
            Icons.error_outline_rounded,
            errorMessage!,
            statusColors.dangerContainer,
            statusColors.onDangerContainer,
          )
        : hasPendingWrites
        ? (
            Icons.sync_problem_rounded,
            'Modifiche non ancora sincronizzate',
            statusColors.warningContainer,
            statusColors.onWarningContainer,
          )
        : (
            Icons.cloud_off_rounded,
            // Offline: se sappiamo quando i dati sono stati sincronizzati
            // l'ultima volta, lo mostriamo (UC2-E1).
            lastUpdated != null
                ? 'Offline · ultimo aggiornamento ${DateFormatter.dateTimeLabel(lastUpdated!)}'
                : 'Offline · dati dalla memoria locale',
            statusColors.infoContainer,
            statusColors.onInfoContainer,
          );

    // Banner arrotondato e rientrato, coerente col linguaggio a card glass:
    // stessi colori semantici, raggio delle card e una hairline che ne
    // definisce la forma sul gradiente dello sfondo.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        0,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: foreground.withValues(alpha: 0.20)),
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
      ),
    );
  }
}
