import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Logo di ShiftFlow: una "S" disegnata come onda che scorre, affiancata da
/// due onde-eco più sottili. Richiama il "flow" dei turni che si susseguono.
///
/// È un [CustomPaint], quindi è nitido a qualunque dimensione: 24px nella UI
/// come 1024px per l'icona dell'app (vedi test/tools/render_app_icon_test.dart).
class ShiftFlowLogo extends StatelessWidget {
  final double size;

  /// Versione a un solo colore (serve per l'icona "a tema" di Android 13+
  /// e ovunque serva una silhouette).
  final bool monochrome;
  final Color monochromeColor;

  const ShiftFlowLogo({
    super.key,
    this.size = 64,
    this.monochrome = false,
    this.monochromeColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logo ShiftFlow',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: ShiftFlowLogoPainter(
          monochrome: monochrome,
          monochromeColor: monochromeColor,
        ),
      ),
    );
  }
}

class ShiftFlowLogoPainter extends CustomPainter {
  final bool monochrome;
  final Color monochromeColor;

  const ShiftFlowLogoPainter({
    this.monochrome = false,
    this.monochromeColor = Colors.white,
  });

  /// La curva a "S", in coordinate proporzionali (0..1) moltiplicate per il
  /// lato del canvas. [dx]/[dy] spostano l'intera curva: servono per le
  /// onde-eco sopra e sotto quella principale.
  Path _wave(double s, double dx, double dy) {
    Offset p(double x, double y) => Offset((x + dx) * s, (y + dy) * s);
    return Path()
      ..moveTo(p(0.76, 0.26).dx, p(0.76, 0.26).dy)
      ..cubicTo(
        p(0.58, 0.10).dx,
        p(0.58, 0.10).dy,
        p(0.24, 0.14).dx,
        p(0.24, 0.14).dy,
        p(0.26, 0.34).dx,
        p(0.26, 0.34).dy,
      )
      ..cubicTo(
        p(0.28, 0.52).dx,
        p(0.28, 0.52).dy,
        p(0.72, 0.48).dx,
        p(0.72, 0.48).dy,
        p(0.74, 0.66).dx,
        p(0.74, 0.66).dy,
      )
      ..cubicTo(
        p(0.76, 0.86).dx,
        p(0.76, 0.86).dy,
        p(0.42, 0.90).dx,
        p(0.42, 0.90).dy,
        p(0.24, 0.74).dx,
        p(0.24, 0.74).dy,
      );
  }

  Paint _stroke(double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;

    if (monochrome) {
      canvas.drawPath(
        _wave(s, -0.075, -0.075),
        _stroke(0.055 * s)..color = monochromeColor,
      );
      canvas.drawPath(
        _wave(s, 0.075, 0.075),
        _stroke(0.055 * s)..color = monochromeColor,
      );
      canvas.drawPath(
        _wave(s, 0, 0),
        _stroke(0.15 * s)..color = monochromeColor,
      );
      return;
    }

    // Eco superiore: più chiara e sottile, come un riflesso.
    canvas.drawPath(
      _wave(s, -0.075, -0.075),
      _stroke(0.055 * s)..color = AppColors.emerald300.withValues(alpha: 0.85),
    );
    // Eco inferiore: più scura, come un'ombra dell'onda.
    canvas.drawPath(
      _wave(s, 0.075, 0.075),
      _stroke(0.055 * s)..color = AppColors.emerald700.withValues(alpha: 0.75),
    );
    // Onda principale con il gradiente del brand.
    canvas.drawPath(
      _wave(s, 0, 0),
      _stroke(0.15 * s)
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.emerald300,
            AppColors.emerald600,
            AppColors.emerald900,
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant ShiftFlowLogoPainter oldDelegate) =>
      oldDelegate.monochrome != monochrome ||
      oldDelegate.monochromeColor != monochromeColor;
}
