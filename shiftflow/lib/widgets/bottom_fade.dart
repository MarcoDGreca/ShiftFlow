import 'package:flutter/material.dart';

/// Sfuma in trasparenza il fondo di una lista che scorre sotto un
/// FloatingActionButton.
///
/// Senza, le card di vetro passano dietro al pulsante e il suo bordo le
/// "affetta": si vede mezza card, con un taglio netto e innaturale. Qui invece
/// svaniscono gradualmente prima di arrivarci.
///
/// [fadeHeight] è l'altezza della zona sfumata, misurata dal fondo: vuole lo
/// stesso valore del padding inferiore della lista (di norma
/// `AppSizes.fabClearance + insets.bottom`). Così a fine scorrimento l'ultimo
/// elemento si ferma esattamente dove la sfumatura comincia, e resta pieno.
class BottomFade extends StatelessWidget {
  final double fadeHeight;
  final Widget child;

  const BottomFade({super.key, required this.fadeHeight, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        // Altezza illimitata o degenere: niente da sfumare, e il rapporto
        // sotto non avrebbe senso.
        if (!height.isFinite || height <= 0) return child;

        // Il gradiente ragiona in frazioni dell'altezza, noi in pixel.
        final stop = (fadeHeight / height).clamp(0.0, 1.0);

        return ShaderMask(
          // dstIn: l'alfa del gradiente diventa l'alfa della lista. Nero
          // (opaco) = si vede, trasparente = sparisce.
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: const [Colors.transparent, Colors.black],
            stops: [0.0, stop],
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}
