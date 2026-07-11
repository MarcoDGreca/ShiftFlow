import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_status_colors.dart';
import 'app_typography.dart';

/// Tema centralizzato dell'app (light + dark).
///
/// Tenere il tema in un unico punto significa che colori e stili si cambiano
/// una volta sola e valgono per tutte le schermate. Le due varianti nascono
/// dalla stessa funzione [_base]: cambia solo lo schema colori.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _base(_lightScheme, StatusColors.light);

  static ThemeData get dark => _base(_darkScheme, StatusColors.dark);

  /// Schema colori chiaro: generato dal seme smeraldo, con il primario
  /// scurito a mano per garantire contrasto AA sul bianco.
  static final ColorScheme _lightScheme =
      ColorScheme.fromSeed(seedColor: AppColors.emerald600).copyWith(
        primary: AppColors.emerald700,
        primaryContainer: AppColors.emerald200,
        onPrimaryContainer: AppColors.emerald900,
      );

  /// Schema colori scuro: primario chiaro e luminoso su superfici
  /// verde-carbone molto scure.
  static final ColorScheme _darkScheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.emerald600,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.emerald400,
        onPrimary: const Color(0xFF04382B),
        primaryContainer: AppColors.emerald800,
        onPrimaryContainer: AppColors.emerald200,
        surface: AppColors.darkSurface,
      );

  static ThemeData _base(ColorScheme scheme, StatusColors statusColors) {
    final isDark = scheme.brightness == Brightness.dark;

    // Il TextTheme di partenza porta i colori giusti per la luminosità
    // scelta; sopra ci applichiamo il font Manrope.
    final baseText = ThemeData(brightness: scheme.brightness).textTheme;
    final textTheme = AppTypography.textTheme(baseText);

    // Riempimento traslucido dei campi di testo: sul glass e sul gradiente
    // deve "galleggiare" senza coprire lo sfondo.
    final fieldFill = isDark
        ? AppColors.glassTintDark.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.60);

    OutlineInputBorder inputBorder(Color color, double width) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: width == 0
            ? BorderSide.none
            : BorderSide(color: color, width: width),
      );
    }

    RoundedRectangleBorder shape(double radius) =>
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      extensions: [statusColors],

      // Transizioni di pagina native per ciascuna piattaforma:
      // effetto Cupertino su iOS, "predictive back" su Android.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      // La barra superiore è trasparente: il vetro lo mette GlassContainer
      // nelle schermate (Fase 2); qui evitiamo solo che Material la colori.
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
        foregroundColor: scheme.onSurface,
      ),

      // Anche la barra di navigazione è trasparente per lo stesso motivo.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: (isDark ? AppColors.glassTintDark : Colors.white).withValues(
          alpha: isDark ? 0.60 : 0.65,
        ),
        surfaceTintColor: Colors.transparent,
        shape: shape(AppRadius.md),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        border: inputBorder(scheme.outline, 0),
        enabledBorder: inputBorder(scheme.outline, 0),
        focusedBorder: inputBorder(scheme.primary, 1.5),
        errorBorder: inputBorder(scheme.error, 1),
        focusedErrorBorder: inputBorder(scheme.error, 1.5),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, AppSizes.minTapTarget),
          shape: shape(AppRadius.md),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, AppSizes.minTapTarget),
          shape: shape(AppRadius.md),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, AppSizes.minTapTarget),
          shape: shape(AppRadius.md),
          textStyle: textTheme.labelLarge,
        ),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(64, AppSizes.minTapTarget),
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        labelStyle: textTheme.labelMedium,
      ),

      dialogTheme: DialogThemeData(
        shape: shape(AppRadius.lg),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        elevation: 2,
        highlightElevation: 4,
        shape: shape(AppRadius.lg),
        extendedTextStyle: textTheme.labelLarge,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: shape(AppRadius.md),
        insetPadding: const EdgeInsets.all(AppSpacing.md),
      ),

      popupMenuTheme: PopupMenuThemeData(
        shape: shape(AppRadius.md),
        surfaceTintColor: Colors.transparent,
      ),

      listTileTheme: ListTileThemeData(iconColor: scheme.onSurfaceVariant),
    );
  }
}
