import 'package:flutter/material.dart';

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

    // Le scritture in coda sono l'informazione più importante da dare.
    final (icon, text) = hasPendingWrites
        ? (Icons.sync_problem, 'Modifiche non ancora sincronizzate')
        : (Icons.cloud_off, 'Offline · dati dalla memoria locale');

    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
