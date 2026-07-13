import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';

/// Vista riutilizzabile per gli stati vuoti o d'errore delle sezioni.
/// Mostra un'icona in un cerchio tenue, un titolo e una breve descrizione.
///
/// Con [actionLabel] e [onAction] compare anche un pulsante: un "empty state
/// azionabile" non lascia l'utente in un vicolo cieco ma gli offre subito il
/// passo successivo (regola base: ogni schermata ha un'azione chiara).
class PlaceholderView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  /// Etichetta del pulsante d'azione (facoltativo, va in coppia con [onAction]).
  final String? actionLabel;

  /// Icona del pulsante d'azione.
  final IconData? actionIcon;

  /// Cosa fare al tocco del pulsante d'azione.
  final VoidCallback? onAction;

  const PlaceholderView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      // Scrollabile: con testi ingranditi (accessibilità) il contenuto
      // può superare lo spazio disponibile senza andare in overflow.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
              ),
              child: Icon(icon, size: 48, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.tonalIcon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.add_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
