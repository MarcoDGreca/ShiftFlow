import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_status_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/dialogs.dart';
import '../../models/shift.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/placeholder_view.dart';
import '../../widgets/sync_status_banner.dart';
import 'shift_form_screen.dart';

/// Sezione "Calendario" del Responsabile: griglia mensile con un pallino per
/// ogni turno e, sotto, l'elenco dei turni del giorno selezionato.
/// Da qui si crea (FAB, con la data già impostata), si modifica (tap sulla
/// card) e si elimina (menù sulla card) un turno.
class CalendarioTab extends StatefulWidget {
  const CalendarioTab({super.key});

  @override
  State<CalendarioTab> createState() => _CalendarioTabState();
}

class _CalendarioTabState extends State<CalendarioTab> {
  /// Il mese mostrato dalla griglia e il giorno selezionato.
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Avvia le sottoscrizioni (idempotenti: se già attive non fanno nulla).
    // Lo staff serve per mostrare il nome accanto a ogni turno e per il form.
    // A fine frame: il provider fa notifyListeners() subito, e farlo durante
    // la costruzione del widget non è permesso.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) {
        context.read<ShiftProvider>().listenForRestaurant(user.restaurantId);
        context.read<StaffProvider>().listenForRestaurant(user.restaurantId);
      }
    });
  }

  Future<void> _confirmDelete(Shift shift) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Eliminare il turno?',
      message: 'Questa operazione non si può annullare.',
      confirmLabel: 'Elimina',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final ok = await context.read<ShiftProvider>().deleteShift(shift.id);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<ShiftProvider>().errorMessage ??
                'Eliminazione non riuscita.',
          ),
        ),
      );
    }
  }

  void _openForm({Shift? existing}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        // Un nuovo turno parte dal giorno selezionato sul calendario.
        builder: (_) =>
            ShiftFormScreen(existing: existing, initialDate: _selectedDay),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shiftProvider = context.watch<ShiftProvider>();
    final staffProvider = context.watch<StaffProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Le barre della home sono trasparenti: il contenuto fisso deve partire
    // sotto la AppBar e la lista finire oltre la NavigationBar.
    final insets = MediaQuery.paddingOf(context);

    final selectedShifts = shiftProvider.shiftsOn(_selectedDay);
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: insets.top),
          SyncStatusBanner(
            isFromCache: shiftProvider.isFromCache,
            hasPendingWrites: shiftProvider.hasPendingWrites,
          ),
          if (shiftProvider.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (shiftProvider.errorMessage != null &&
              shiftProvider.shifts.isEmpty)
            Expanded(
              child: PlaceholderView(
                icon: Icons.error_outline_rounded,
                title: 'Qualcosa è andato storto',
                subtitle: shiftProvider.errorMessage!,
              ),
            )
          else ...[
            GlassCard(
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
                0,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xs,
              ),
              child: TableCalendar<Shift>(
                firstDay: now.subtract(const Duration(days: 365 * 2)),
                lastDay: now.add(const Duration(days: 365 * 2)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                onDaySelected: (selected, focused) => setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                }),
                onPageChanged: (focused) => _focusedDay = focused,
                startingDayOfWeek: StartingDayOfWeek.monday,
                // Solo vista mensile: niente pulsante per cambiare formato.
                availableCalendarFormats: const {CalendarFormat.month: 'Mese'},
                // Un pallino per ogni turno del giorno (massimo 3).
                eventLoader: shiftProvider.shiftsOn,
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  // Testi italiani senza package intl: usiamo i nostri
                  // formatter al posto di quelli basati sul locale.
                  titleTextFormatter: (date, _) =>
                      DateFormatter.monthYear(date),
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
                  markerDecoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary,
                  ),
                  markersMaxCount: 3,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Text(
                DateFormatter.full(_selectedDay),
                style: theme.textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: selectedShifts.isEmpty
                  // Il padding tiene il messaggio centrato SOPRA il FAB.
                  ? Padding(
                      padding: EdgeInsets.only(
                        bottom: AppSizes.fabClearance + insets.bottom,
                      ),
                      child: const PlaceholderView(
                        icon: Icons.event_busy_rounded,
                        title: 'Nessun turno in questo giorno',
                        subtitle: 'Tocca + per creare un turno in questa data.',
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        0,
                        AppSpacing.sm,
                        AppSizes.fabClearance + insets.bottom,
                      ),
                      itemCount: selectedShifts.length,
                      itemBuilder: (context, i) {
                        final shift = selectedShifts[i];
                        final employeeName =
                            staffProvider.byUid(shift.employeeUid)?.name ??
                            'Dipendente';
                        return _ShiftCard(
                          shift: shift,
                          employeeName: employeeName,
                          onEdit: () => _openForm(existing: shift),
                          onDelete: () => _confirmDelete(shift),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
      // Il Padding alza il FAB sopra la NavigationBar trasparente della home
      // (lo Scaffold interno non sa quanto è alta: glielo diciamo noi).
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: insets.bottom),
        child: FloatingActionButton.extended(
          onPressed: _openForm,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nuovo turno'),
        ),
      ),
    );
  }
}

/// Card di un turno nel giorno selezionato: tap per modificare, menù per
/// modificare/eliminare (niente azioni distruttive "nude" dentro la riga).
class _ShiftCard extends StatelessWidget {
  final Shift shift;
  final String employeeName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ShiftCard({
    required this.shift,
    required this.employeeName,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      onTap: onEdit,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          InitialsAvatar(name: employeeName),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(employeeName, style: theme.textTheme.titleMedium),
                Text(
                  '${shift.startTime}–${shift.endTime}'
                  '${shift.notes != null ? ' · ${shift.notes}' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Azioni turno',
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Modifica')),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Elimina',
                  style: TextStyle(color: theme.statusColors.danger),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
