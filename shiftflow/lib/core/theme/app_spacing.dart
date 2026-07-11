import 'package:flutter/material.dart';

/// Scala di spaziature dell'app: usare sempre questi valori al posto di
/// numeri "magici" sparsi nel codice, così il ritmo visivo resta coerente.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Padding standard delle schermate con form.
  static const EdgeInsets screenPadding = EdgeInsets.all(lg);

  /// Padding standard delle liste (con spazio extra in fondo per il FAB).
  static const EdgeInsets listPadding = EdgeInsets.fromLTRB(
    sm,
    sm,
    sm,
    AppSizes.fabClearance,
  );
}

/// Raggi degli angoli arrotondati.
abstract final class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
}

/// Dimensioni fisse ricorrenti.
abstract final class AppSizes {
  /// Dimensione minima di un elemento toccabile (linee guida accessibilità).
  static const double minTapTarget = 48;

  /// Spazio da lasciare in fondo alle liste perché l'ultimo elemento
  /// non resti nascosto dietro il FloatingActionButton.
  static const double fabClearance = 88;
}
