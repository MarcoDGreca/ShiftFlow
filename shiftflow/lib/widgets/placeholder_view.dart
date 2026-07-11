import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';

/// Vista riutilizzabile per gli stati vuoti o d'errore delle sezioni.
/// Mostra un'icona in un cerchio tenue, un titolo e una breve descrizione.
class PlaceholderView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const PlaceholderView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
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
          ],
        ),
      ),
    );
  }
}
