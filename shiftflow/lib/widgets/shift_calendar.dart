import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../core/theme/app_spacing.dart';
import '../core/theme/app_status_colors.dart';
import '../core/utils/date_formatter.dart';
import '../models/leave_request.dart';
import '../models/shift.dart';
import 'glass_container.dart';

/// Calendario in stile app, condiviso tra la vista "Calendario" del
/// Responsabile e la vista "I miei turni" del Dipendente.
///
/// Centralizza qui tutta la grafica (intestazione in italiano senza `intl`,
/// pallini di turni e assenze, giorno selezionato/oggi): una modifica al look
/// del calendario si fa in un punto solo.
///
/// Il calendario ha due formati — **mese** e **settimana** — commutabili dal
/// pulsante nell'intestazione. La settimana occupa una sola riga: lascia molto
/// più spazio all'elenco del giorno, utile soprattutto al Responsabile
/// ([startWithWeekView]).
///
/// I pallini in fondo a ogni giorno codificano cosa c'è quel giorno:
///  - **turni**: fino a 3 pallini nel colore primario;
///  - **ferie**/**permessi** approvati (via [leaveLoader]): un pallino nel
///    colore dedicato. Con [leaveLoader] valorizzato compare anche una legenda.
class ShiftCalendar extends StatefulWidget {
  /// Il mese mostrato dalla griglia.
  final DateTime focusedDay;

  /// Il giorno attualmente selezionato (cerchiato).
  final DateTime selectedDay;

  /// Chiamato quando si tocca un giorno: `(selezionato, mese in vista)`.
  final void Function(DateTime selected, DateTime focused) onDaySelected;

  /// Chiamato quando si scorre a un altro mese.
  final ValueChanged<DateTime>? onPageChanged;

  /// Restituisce i turni di un giorno: alimenta i pallini dei turni.
  final List<Shift> Function(DateTime day) eventLoader;

  /// Restituisce le assenze (ferie/permessi) approvate di un giorno. Se `null`
  /// il calendario mostra solo i turni (nessun pallino assenze, nessuna legenda).
  final List<LeaveRequest> Function(DateTime day)? leaveLoader;

  /// Parte in vista settimanale (una riga sola) invece che mensile.
  final bool startWithWeekView;

  /// Margine esterno della card che contiene il calendario.
  final EdgeInsetsGeometry margin;

  const ShiftCalendar({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
    required this.eventLoader,
    this.leaveLoader,
    this.onPageChanged,
    this.startWithWeekView = false,
    this.margin = const EdgeInsets.fromLTRB(
      AppSpacing.sm,
      AppSpacing.sm,
      AppSpacing.sm,
      0,
    ),
  });

  @override
  State<ShiftCalendar> createState() => _ShiftCalendarState();
}

class _ShiftCalendarState extends State<ShiftCalendar> {
  /// Formato corrente (mese/settimana): stato interno del widget, si cambia
  /// dal pulsante nell'intestazione del calendario.
  late CalendarFormat _format = widget.startWithWeekView
      ? CalendarFormat.week
      : CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statusColors = theme.statusColors;
    final now = DateTime.now();

    return GlassCard(
      margin: widget.margin,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        // Si adatta all'altezza del calendario (+ legenda): senza `min` una
        // Column pretende altezza illimitata e va in overflow.
        mainAxisSize: MainAxisSize.min,
        children: [
          TableCalendar<Shift>(
            firstDay: now.subtract(const Duration(days: 365 * 2)),
            lastDay: now.add(const Duration(days: 365 * 2)),
            focusedDay: widget.focusedDay,
            selectedDayPredicate: (day) => isSameDay(day, widget.selectedDay),
            onDaySelected: widget.onDaySelected,
            onPageChanged: widget.onPageChanged,
            startingDayOfWeek: StartingDayOfWeek.monday,
            // Due formati commutabili dal pulsante nell'intestazione: il mese
            // per la panoramica, la settimana per lasciare spazio alla lista.
            availableCalendarFormats: const {
              CalendarFormat.month: 'Mese',
              CalendarFormat.week: 'Settimana',
            },
            calendarFormat: _format,
            onFormatChanged: (format) => setState(() => _format = format),
            // L'altezza di default (16) taglia le lettere dei giorni.
            daysOfWeekHeight: 24,
            eventLoader: widget.eventLoader,
            calendarBuilders: CalendarBuilders<Shift>(
              // Disegniamo noi i pallini: turni (primario) + assenze (colori
              // dedicati). Chiamato per ogni giorno, anche senza turni, così le
              // assenze compaiono pure nei giorni liberi.
              markerBuilder: (context, day, shifts) {
                final leaves =
                    widget.leaveLoader?.call(day) ?? const <LeaveRequest>[];
                if (shifts.isEmpty && leaves.isEmpty) return null;

                // Sul giorno selezionato lo sfondo è primario: un pallino
                // primario sparirebbe, quindi lo schiariamo.
                final isSelected = isSameDay(day, widget.selectedDay);
                final shiftColor = isSelected ? scheme.onPrimary : scheme.primary;

                final dots = <Widget>[
                  for (var i = 0; i < shifts.length && i < 3; i++)
                    _MarkerDot(color: shiftColor),
                  if (leaves.any((l) => l.isFerie))
                    _MarkerDot(color: statusColors.info),
                  if (leaves.any((l) => l.isPermesso))
                    _MarkerDot(color: statusColors.warning),
                ];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: dots),
                );
              },
            ),
            headerStyle: HeaderStyle(
              // Il pulsante mostra il formato ATTUALE (non il prossimo) e
              // commuta mese/settimana: capsula discreta con bordo sottile.
              formatButtonVisible: true,
              formatButtonShowsNext: false,
              formatButtonDecoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: const BorderRadius.all(Radius.circular(999)),
              ),
              formatButtonTextStyle: theme.textTheme.labelMedium!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              titleCentered: false,
              // Testi italiani senza package intl: usiamo i nostri formatter al
              // posto di quelli basati sul locale.
              titleTextFormatter: (date, _) => DateFormatter.monthYear(date),
              titleTextStyle: theme.textTheme.titleMedium!,
              leftChevronIcon: Icon(
                Icons.chevron_left_rounded,
                color: scheme.onSurfaceVariant,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              dowTextFormatter: (date, _) => DateFormatter.dowLetter(date),
              weekdayStyle: theme.textTheme.labelMedium!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              weekendStyle: theme.textTheme.labelMedium!.copyWith(
                color: scheme.primary,
              ),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              // Colori dei numeri presi dal tema: i grigi di default del
              // pacchetto stonano in dark mode.
              defaultTextStyle: TextStyle(color: scheme.onSurface),
              weekendTextStyle: TextStyle(color: scheme.onSurface),
              disabledTextStyle: TextStyle(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              todayDecoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: scheme.primary, width: 1.5),
              ),
              todayTextStyle: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
              selectedDecoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary,
              ),
              selectedTextStyle: TextStyle(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (widget.leaveLoader != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: [
                  _LegendItem(color: scheme.primary, label: 'Turno'),
                  _LegendItem(color: statusColors.info, label: 'Ferie'),
                  _LegendItem(color: statusColors.warning, label: 'Permesso'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Pallino indicatore in fondo a un giorno del calendario.
class _MarkerDot extends StatelessWidget {
  final Color color;

  const _MarkerDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 0.5),
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// Voce della legenda: pallino colorato + etichetta.
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MarkerDot(color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
