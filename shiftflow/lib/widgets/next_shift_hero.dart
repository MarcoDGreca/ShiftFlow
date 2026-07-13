import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/date_formatter.dart';
import '../models/shift.dart';
import 'info_pill.dart';

/// Card "in evidenza" con il prossimo turno del dipendente.
///
/// È il pattern "Up Next" delle app di turni (When I Work, Deputy): la domanda
/// più frequente di chi lavora a turni è "quando lavoro?", quindi la risposta
/// sta in cima, grande e col colore del brand. È l'UNICO elemento a tinta
/// piena della schermata: tutto il resto è su vetro, così la gerarchia è
/// inequivocabile (una sola cosa "urla", le altre parlano).
class NextShiftHero extends StatelessWidget {
  final Shift shift;

  /// Tocco sulla card (apre il dettaglio del turno).
  final VoidCallback? onTap;

  final EdgeInsetsGeometry margin;

  const NextShiftHero({
    super.key,
    required this.shift,
    this.onTap,
    this.margin = const EdgeInsets.symmetric(
      horizontal: AppSpacing.xs,
      vertical: AppSpacing.xs,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Verdi profondi in entrambe le modalità: il testo bianco resta leggibile
    // (contrasto ≥ 4.5:1) e la card spicca sia sul chiaro che sullo scuro.
    final gradientColors = isDark
        ? const [AppColors.emerald800, AppColors.emerald950]
        : const [AppColors.emerald700, AppColors.emerald900];

    // "Oggi"/"Domani" se possibile, altrimenti la data compatta.
    final when = DateFormatter.relativeDay(shift.date) ??
        DateFormatter.dayMonthShort(shift.date);
    final duration = DateFormatter.durationLabel(
      shift.startTime,
      shift.endTime,
    );
    final notes = shift.notes?.trim();

    const radius = BorderRadius.all(Radius.circular(AppRadius.lg));

    return Padding(
      padding: margin,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'PROSSIMO TURNO',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      InfoPill(
                        icon: Icons.event_rounded,
                        label: when,
                        background: Colors.white.withValues(alpha: 0.18),
                        foreground: Colors.white,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          DateFormatter.timeRange(
                            shift.startTime,
                            shift.endTime,
                          ),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Data per esteso + durata: il contesto sotto il "titolo".
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        DateFormatter.full(shift.date),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      if (duration != null)
                        InfoPill(
                          icon: Icons.timelapse_rounded,
                          label: duration,
                          background: Colors.white.withValues(alpha: 0.18),
                          foreground: Colors.white,
                        ),
                    ],
                  ),
                  if (notes != null && notes.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.notes_rounded,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            notes,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
