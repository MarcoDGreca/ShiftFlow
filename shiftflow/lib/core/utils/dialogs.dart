import 'package:flutter/material.dart';

import '../../widgets/glass_container.dart';
import '../theme/app_spacing.dart';
import '../theme/app_status_colors.dart';

/// Dialogo di conferma standard dell'app, in stile glass.
///
/// Ritorna `true` solo se l'utente conferma. Con [destructive] il pulsante
/// di conferma diventa rosso, per le azioni irreversibili (eliminazioni).
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Annulla',
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final isDark = theme.brightness == Brightness.dark;
      final confirmStyle = destructive
          ? FilledButton.styleFrom(
              backgroundColor: theme.statusColors.danger,
              // In dark mode il rosso è chiaro: serve testo scuro per leggerlo.
              foregroundColor: isDark ? const Color(0xFF450A0A) : Colors.white,
            )
          : null;

      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: GlassContainer(
          // Unico blur "ammesso" fuori dalle barre: il dialogo è una sola
          // superficie, disegnata sopra tutto il resto.
          blur: true,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              Text(message, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(cancelLabel),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    style: confirmStyle,
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(confirmLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return confirmed ?? false;
}
