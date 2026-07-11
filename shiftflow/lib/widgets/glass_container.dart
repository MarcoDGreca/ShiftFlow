import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// True se l'utente ha chiesto al sistema più contrasto o meno animazioni:
/// in quel caso il "vetro" diventa una superficie opaca e leggibile
/// (fallback di accessibilità).
bool reduceTransparency(BuildContext context) {
  return MediaQuery.highContrastOf(context) ||
      MediaQuery.disableAnimationsOf(context);
}

/// Superficie in stile "Liquid Glass": tinta traslucida, riflesso morbido
/// e bordo speculare. Con [blur] attivo sfoca anche ciò che le sta dietro
/// (BackdropFilter): è costoso, quindi va usato SOLO sulla "chrome"
/// dell'app (barre, dialoghi), mai dentro le liste.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;

  /// Sfocatura vera di ciò che sta dietro. Riservata a barre e dialoghi.
  final bool blur;

  /// Bordo "speculare" a gradiente spesso 1px. Disattivarlo per le barre
  /// a tutta larghezza, dove un bordo su ogni lato stonerebbe.
  final bool showBorder;

  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.md)),
    this.blur = false,
    this.showBorder = true,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final opaque = reduceTransparency(context);
    final tint = isDark ? AppColors.glassTintDark : AppColors.glassTintLight;

    // Le superfici sfocate possono essere più trasparenti; quelle senza blur
    // ("fake glass" delle card) hanno bisogno di più tinta per la leggibilità.
    final double alpha = opaque
        ? 1.0
        : blur
        ? (isDark ? 0.50 : 0.55)
        : (isDark ? 0.60 : 0.65);

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        // Leggero "riflesso" dall'alto verso il basso: la tinta è un filo
        // più densa in alto, come luce che colpisce il vetro.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tint.withValues(alpha: (alpha + 0.10).clamp(0.0, 1.0)),
            tint.withValues(alpha: alpha),
          ],
        ),
      ),
      // Material trasparente: serve ai figli come ListTile e InkWell,
      // che richiedono un antenato Material per disegnare i loro effetti.
      child: Material(type: MaterialType.transparency, child: child),
    );

    if (blur && !opaque) {
      content = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: content,
      );
    }

    // Il clip serve sia per gli angoli sia per delimitare il BackdropFilter.
    content = ClipRRect(borderRadius: borderRadius, child: content);

    if (!showBorder) {
      if (margin != null) {
        return Padding(padding: margin!, child: content);
      }
      return content;
    }

    // Bordo speculare: un gradiente chiaro (più luminoso in alto a sinistra)
    // che spunta per 1px tutt'attorno al contenuto ritagliato.
    final List<Color> borderColors = opaque
        ? [theme.colorScheme.outlineVariant, theme.colorScheme.outlineVariant]
        : [
            Colors.white.withValues(alpha: isDark ? 0.25 : 0.55),
            Colors.white.withValues(alpha: isDark ? 0.06 : 0.10),
          ];

    return Container(
      margin: margin,
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: borderColors,
        ),
      ),
      child: content,
    );
  }
}

/// Variante "card" del vetro, pensata per le liste: niente blur (troppo
/// costoso ripetuto molte volte), margini da lista e tap opzionale.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin = const EdgeInsets.symmetric(
      horizontal: AppSpacing.xs,
      vertical: AppSpacing.xs,
    ),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(AppRadius.md));

    Widget content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }
    if (onTap != null) {
      content = InkWell(onTap: onTap, borderRadius: radius, child: content);
    }

    return GlassContainer(borderRadius: radius, margin: margin, child: content);
  }
}

/// Sfondo vetro per una AppBar: da passare come `flexibleSpace`, riempie
/// l'intera barra (status bar inclusa) e sfoca ciò che ci scorre sotto.
class GlassBarBackground extends StatelessWidget {
  const GlassBarBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const GlassContainer(
      blur: true,
      borderRadius: BorderRadius.zero,
      showBorder: false,
      child: SizedBox.expand(),
    );
  }
}
