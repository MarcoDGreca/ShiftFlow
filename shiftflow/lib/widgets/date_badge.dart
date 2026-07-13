import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import '../core/utils/date_formatter.dart';

/// Blocco data compatto (giorno della settimana, numero, mese) usato come
/// elemento a sinistra delle card dei turni e nel dettaglio turno.
///
/// Con [highlight] (il giorno è oggi) si accende: sfondo più pieno e giorno
/// della settimana sostituito da "OGGI". È la gerarchia visiva delle app di
/// turni: ciò che è imminente deve saltare all'occhio prima di tutto il resto.
class DateBadge extends StatelessWidget {
  final DateTime date;

  const DateBadge({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final isToday = DateFormatter.relativeDay(date) == 'Oggi';

    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: isToday ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: isToday
            ? Border.all(color: scheme.primary.withValues(alpha: 0.45))
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isToday ? 'OGGI' : DateFormatter.weekdayShort(date).toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: isToday ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: isToday ? FontWeight.w800 : null,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            '${date.day}',
            style: theme.textTheme.titleLarge?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          Text(
            DateFormatter.monthShort(date),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
