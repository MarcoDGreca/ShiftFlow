import 'package:flutter/material.dart';

/// Colori semantici di stato (successo, attesa, errore, informazione).
///
/// È una [ThemeExtension]: viaggia dentro il tema, quindi i widget la leggono
/// con `Theme.of(context).statusColors` e ottengono automaticamente la
/// variante giusta per light o dark mode. Tutte le coppie container/testo
/// rispettano un contrasto di almeno 4.5:1 (WCAG AA).
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;

  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;

  final Color danger;
  final Color dangerContainer;
  final Color onDangerContainer;

  final Color info;
  final Color infoContainer;
  final Color onInfoContainer;

  const StatusColors({
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.danger,
    required this.dangerContainer,
    required this.onDangerContainer,
    required this.info,
    required this.infoContainer,
    required this.onInfoContainer,
  });

  static const StatusColors light = StatusColors(
    success: Color(0xFF047857),
    successContainer: Color(0xFFD1FAE1),
    onSuccessContainer: Color(0xFF065F46),
    warning: Color(0xFFB45309),
    warningContainer: Color(0xFFFEF3C7),
    onWarningContainer: Color(0xFF92400E),
    danger: Color(0xFFB91C1C),
    dangerContainer: Color(0xFFFEE2E2),
    onDangerContainer: Color(0xFF991B1B),
    info: Color(0xFF1D4ED8),
    infoContainer: Color(0xFFDBEAFE),
    onInfoContainer: Color(0xFF1E40AF),
  );

  static const StatusColors dark = StatusColors(
    success: Color(0xFF34D399),
    successContainer: Color(0xFF064E3B),
    onSuccessContainer: Color(0xFFA7F3D0),
    warning: Color(0xFFFBBF24),
    warningContainer: Color(0xFF78350F),
    onWarningContainer: Color(0xFFFDE68A),
    danger: Color(0xFFF87171),
    dangerContainer: Color(0xFF7F1D1D),
    onDangerContainer: Color(0xFFFECACA),
    info: Color(0xFF60A5FA),
    infoContainer: Color(0xFF1E3A8A),
    onInfoContainer: Color(0xFFBFDBFE),
  );

  @override
  StatusColors copyWith({
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? danger,
    Color? dangerContainer,
    Color? onDangerContainer,
    Color? info,
    Color? infoContainer,
    Color? onInfoContainer,
  }) {
    return StatusColors(
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      danger: danger ?? this.danger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      onDangerContainer: onDangerContainer ?? this.onDangerContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
    );
  }

  @override
  StatusColors lerp(ThemeExtension<StatusColors>? other, double t) {
    if (other is! StatusColors) return this;
    return StatusColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      onDangerContainer: Color.lerp(
        onDangerContainer,
        other.onDangerContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
    );
  }
}

/// Scorciatoia: `Theme.of(context).statusColors` invece della più verbosa
/// `Theme.of(context).extension<StatusColors>()!`.
extension StatusColorsGetter on ThemeData {
  StatusColors get statusColors =>
      extension<StatusColors>() ??
      (brightness == Brightness.dark ? StatusColors.dark : StatusColors.light);
}
