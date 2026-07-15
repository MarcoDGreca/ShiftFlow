import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import 'app_background.dart';
import 'glass_container.dart';

/// Impalcatura condivisa dei form a tutta pagina (registrazione, nuova
/// richiesta, turno, modifica profilo): AppBar su vetro, sfondo dell'app e una
/// card di vetro centrata e vincolata in larghezza che contiene il [child]
/// (di norma un [Form]). Centralizza padding, larghezza massima e raggi così
/// che tutti i form abbiano lo stesso aspetto.
class GlassFormScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const GlassFormScaffold({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Con extendBodyBehindAppBar il contenuto parte da sotto la barra: il
    // padding in alto deve scavalcare sia la status bar (`viewPadding.top`) sia
    // l'AppBar stessa, altrimenti il primo campo le finisce dietro. `bottom`
    // tiene il pulsante sopra la barra gesti su schermi piccoli.
    final viewPadding = MediaQuery.paddingOf(context);
    final appBarHeight = viewPadding.top + kToolbarHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(title),
        flexibleSpace: const GlassBarBackground(),
      ),
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              appBarHeight + AppSpacing.lg,
              AppSpacing.lg,
              viewPadding.bottom + AppSpacing.lg,
            ),
            child: ConstrainedBox(
              // Su schermi larghi (tablet) il form non si allarga a nastro.
              constraints: const BoxConstraints(maxWidth: 420),
              child: GlassContainer(
                blur: true,
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.xl),
                ),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
