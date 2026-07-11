import 'package:flutter/material.dart';

/// Palette del brand ShiftFlow: scala di verdi smeraldo + colori di supporto.
///
/// Questi sono i "mattoni" grezzi: il resto dell'app non dovrebbe usare
/// direttamente questi valori ma passare sempre dal [ColorScheme] del tema
/// (o da StatusColors per i colori semantici). Tenerli qui in un unico punto
/// permette di ritoccare il brand cambiando una sola riga.
abstract final class AppColors {
  // --- Scala smeraldo (dal più scuro al più chiaro) ---
  static const Color emerald950 = Color(0xFF022C22);
  static const Color emerald900 = Color(0xFF064E3B);
  static const Color emerald800 = Color(0xFF065F46);
  static const Color emerald700 = Color(0xFF047857);
  static const Color emerald600 = Color(0xFF059669); // colore "seme" del tema
  static const Color emerald400 = Color(0xFF34D399);
  static const Color emerald300 = Color(0xFF6EE7B7);
  static const Color emerald200 = Color(0xFFA7F3D0);
  static const Color emerald100 = Color(0xFFD1FAE1);
  static const Color mint50 = Color(0xFFECFDF5);

  // --- Superfici scure (dark mode) ---
  static const Color darkSurface = Color(0xFF101413);
  static const Color darkBackgroundEnd = Color(0xFF0B1210);

  // --- Sfondo ambientale a gradiente (usato da AppBackground) ---
  static const List<Color> backgroundGradientLight = [mint50, Colors.white];
  static const List<Color> backgroundGradientDark = [
    emerald950,
    darkBackgroundEnd,
  ];

  // --- Tinte per le superfici "glass" (usate da GlassContainer) ---
  static const Color glassTintLight = Colors.white;
  static const Color glassTintDark = Color(0xFF1A2420);
}
