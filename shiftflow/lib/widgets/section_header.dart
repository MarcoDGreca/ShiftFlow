import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';

/// Intestazione di sezione per le liste: etichetta piccola in maiuscolo con,
/// a destra, un'informazione di contorno facoltativa (es. un conteggio).
///
/// Serve alla regola del "raggruppamento": una lista lunga si legge meglio se
/// divisa in blocchi con un titolo (es. "In attesa", "Storico"). L'etichetta è
/// volutamente discreta: guida l'occhio senza rubare la scena al contenuto.
class SectionHeader extends StatelessWidget {
  final String title;

  /// Testo secondario a destra (es. "3 in attesa").
  final String? trailing;

  /// Margine esterno; il default allinea l'header alle card delle liste.
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.xs,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                letterSpacing: 0.8,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: theme.textTheme.labelMedium?.copyWith(color: color),
            ),
        ],
      ),
    );
  }
}
