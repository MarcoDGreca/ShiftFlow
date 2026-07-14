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

  /// Avanzamento del disegno (0..1) per la splash animata: l'onda si traccia
  /// nella prima parte, le eco compaiono dopo. Con 1.0 (default) il logo è
  /// quello statico di sempre.
  final double progress;

  const ShiftFlowLogo({
    super.key,
    this.size = 64,
    this.monochrome = false,
    this.monochromeColor = Colors.white,
    this.progress = 1.0,
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
          progress: progress,
        ),
      ),
    );
  }
}

class ShiftFlowLogoPainter extends CustomPainter {
  final bool monochrome;
  final Color monochromeColor;

  /// Vedi [ShiftFlowLogo.progress].
  final double progress;

  const ShiftFlowLogoPainter({
    this.monochrome = false,
    this.monochromeColor = Colors.white,
    this.progress = 1.0,
  });

  // Fasi della timeline, come frazioni di [progress]: prima si traccia
  // l'onda, poi (in parte sovrapposte) compaiono le eco.
  static const _waveEnd = 0.6;
  static const _echoStart = 0.4;
  static const _echoEnd = 0.75;

  /// Il tratto [path] fermato alla frazione [t] della sua lunghezza:
  /// è ciò che dà l'effetto "pennellata che si disegna".
  Path _trim(Path path, double t) {
    if (t >= 1.0) return path;
    final metric = path.computeMetrics().first;
    return metric.extractPath(0, metric.length * t);
  }

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

    // Quanto è tracciata l'onda e quanto sono visibili le eco, derivati
    // dall'unico progress: così il chiamante anima un solo valore.
    final waveT = Curves.easeInOut.transform(
      (progress / _waveEnd).clamp(0.0, 1.0),
    );
    final echoT =
        ((progress - _echoStart) / (_echoEnd - _echoStart)).clamp(0.0, 1.0);

    if (monochrome) {
      // Silhouette pulita: solo l'onda principale, un filo più spessa.
      // Le eco dello stesso colore si fonderebbero in una macchia.
      if (waveT > 0) {
        canvas.drawPath(
          _trim(_wave(s, 0, 0), waveT),
          _stroke(0.17 * s)..color = monochromeColor,
        );
      }
      return;
    }

    if (echoT > 0) {
      // Eco superiore: più chiara e sottile, come un riflesso.
      canvas.drawPath(
        _wave(s, -0.075, -0.075),
        _stroke(0.055 * s)
          ..color = AppColors.emerald300.withValues(alpha: 0.85 * echoT),
      );
      // Eco inferiore: più scura, come un'ombra dell'onda.
      canvas.drawPath(
        _wave(s, 0.075, 0.075),
        _stroke(0.055 * s)
          ..color = AppColors.emerald700.withValues(alpha: 0.75 * echoT),
      );
    }

    // Onda principale con il gradiente del brand.
    if (waveT > 0) {
      canvas.drawPath(
        _trim(_wave(s, 0, 0), waveT),
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
  }

  @override
  bool shouldRepaint(covariant ShiftFlowLogoPainter oldDelegate) =>
      oldDelegate.monochrome != monochrome ||
      oldDelegate.monochromeColor != monochromeColor ||
      oldDelegate.progress != progress;
}
