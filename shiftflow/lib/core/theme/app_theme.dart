import 'package:flutter/material.dart';

/// Tema centralizzato dell'app.
///
/// Tenere il tema in un unico punto significa che colori e stili si cambiano
/// una volta sola e valgono per tutte le schermate.
class AppTheme {
  AppTheme._();

  /// Colore "seme" da cui Material genera l'intera palette (primario,
  /// secondario, superfici, ecc.).
  static const Color _seedColor = Color(0xFF00695C); // teal scuro

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
        appBarTheme: const AppBarTheme(centerTitle: true),
      );
}
