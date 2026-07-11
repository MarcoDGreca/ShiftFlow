import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Sfondo ambientale dell'app: gradiente verticale tenue + due "blob"
/// luminosi decorativi. Dà profondità alle superfici glass che ci
/// galleggiano sopra (il blur ha bisogno di qualcosa da sfocare).
///
/// I blob sono semplici gradienti radiali: molto economici da disegnare,
/// nessun BackdropFilter coinvolto.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark
        ? AppColors.backgroundGradientDark
        : AppColors.backgroundGradientLight;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
              ),
            ),
          ),
        ),
        Positioned(
          top: -90,
          right: -70,
          child: _GlowBlob(
            diameter: 280,
            color: (isDark ? AppColors.emerald700 : AppColors.emerald300)
                .withValues(alpha: isDark ? 0.25 : 0.35),
          ),
        ),
        Positioned(
          bottom: -110,
          left: -80,
          child: _GlowBlob(
            diameter: 340,
            color: (isDark ? AppColors.emerald800 : AppColors.emerald200)
                .withValues(alpha: isDark ? 0.30 : 0.45),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double diameter;
  final Color color;

  const _GlowBlob({required this.diameter, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
