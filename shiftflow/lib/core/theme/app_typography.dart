import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tipografia dell'app: font Manrope su tutta la scala Material,
/// con titoli ed etichette leggermente più "pesanti" per dare carattere.
abstract final class AppTypography {
  /// Costruisce il TextTheme partendo da quello base del tema (che porta
  /// con sé i colori giusti per light/dark) e applicandoci Manrope.
  static TextTheme textTheme(TextTheme base) {
    final manrope = GoogleFonts.manropeTextTheme(base);
    return manrope.copyWith(
      displaySmall: manrope.displaySmall?.copyWith(fontWeight: FontWeight.w800),
      headlineMedium: manrope.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      headlineSmall: manrope.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleLarge: manrope.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: manrope.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: manrope.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: manrope.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: manrope.labelMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
