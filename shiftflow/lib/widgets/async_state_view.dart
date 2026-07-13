import 'package:flutter/material.dart';

import 'placeholder_view.dart';

/// Incapsula il pattern ricorrente delle sezioni con dati in tempo reale:
/// spinner durante il caricamento, messaggio d'errore, stato vuoto e infine
/// il contenuto vero. Prima era copiato-incollato in ogni tab.
class AsyncStateView extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final bool isEmpty;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;

  /// Azione facoltativa dello stato vuoto (es. "Nuova richiesta"): un empty
  /// state con un pulsante suggerisce subito il passo successivo.
  final String? emptyActionLabel;
  final IconData? emptyActionIcon;
  final VoidCallback? onEmptyAction;

  final Widget child;

  const AsyncStateView({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.isEmpty,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.emptyActionLabel,
    this.emptyActionIcon,
    this.onEmptyAction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    // L'errore si mostra solo se non abbiamo nulla da far vedere: dei dati
    // (anche vecchi) sono più utili di un messaggio d'errore a tutto schermo.
    if (errorMessage != null && isEmpty) {
      return PlaceholderView(
        icon: Icons.error_outline_rounded,
        title: 'Qualcosa è andato storto',
        subtitle: errorMessage!,
      );
    }
    if (isEmpty) {
      return PlaceholderView(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
        actionLabel: emptyActionLabel,
        actionIcon: emptyActionIcon,
        onAction: onEmptyAction,
      );
    }
    return child;
  }
}
