import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';

/// Piccola "pillola" icona + testo per metadati compatti: la durata di un
/// turno, il riepilogo del giorno ("3 turni · 12 h"), un'etichetta di stato.
///
/// Un colore tenue e una forma a capsula la distinguono dal testo normale
/// senza competere con le informazioni principali (gerarchia visiva).
class InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  /// Colori personalizzati; se assenti usa un grigio neutro da metadato.
  final Color? background;
  final Color? foreground;

  const InfoPill({
    super.key,
    required this.icon,
    required this.label,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg =
        background ?? scheme.surfaceContainerHighest.withValues(alpha: 0.6);
    final fg = foreground ?? scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
