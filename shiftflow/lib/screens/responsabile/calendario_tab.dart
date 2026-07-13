import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_status_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/dialogs.dart';
import '../../models/shift.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_request_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/leave_day_card.dart';
import '../../widgets/placeholder_view.dart';
import '../../widgets/shift_calendar.dart';
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
        // Assenze approvate del locale, per i marker e il dettaglio del giorno.
        context.read<LeaveRequestProvider>().listenForRestaurant(
          user.restaurantId,
        );
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
    final leaveProvider = context.watch<LeaveRequestProvider>();

    // Le barre della home sono trasparenti: il contenuto fisso deve partire
    // sotto la AppBar e la lista finire oltre la NavigationBar.
    final insets = MediaQuery.paddingOf(context);

    final selectedShifts = shiftProvider.shiftsOn(_selectedDay);
    final selectedLeaves = leaveProvider.approvedLeavesOn(_selectedDay);

    // I turni futuri di un membro disattivato vanno segnalati "da riassegnare"
    // (UC5, flusso alternativo). Tutti i turni mostrati sono del giorno scelto:
    // basta sapere se quel giorno è da oggi in poi.
    final now = DateTime.now();
    final selectedDay = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    final selectedIsFuture = !selectedDay.isBefore(
      DateTime(now.year, now.month, now.day),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: insets.top),
          SyncStatusBanner(
            isFromCache: shiftProvider.isFromCache,
            hasPendingWrites: shiftProvider.hasPendingWrites,
            lastUpdated: shiftProvider.lastSyncedAt,
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
            ShiftCalendar(
              focusedDay: _focusedDay,
              selectedDay: _selectedDay,
              onDaySelected: (selected, focused) => setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              }),
              onPageChanged: (focused) => _focusedDay = focused,
              eventLoader: shiftProvider.shiftsOn,
              leaveLoader: leaveProvider.approvedLeavesOn,
              // Il responsabile lavora giorno per giorno: la vista settimana
              // (una riga) lascia lo spazio all'elenco. Il mese resta a un
              // tocco dal pulsante nell'intestazione.
              startWithWeekView: true,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: _DayHeader(
                day: _selectedDay,
                shifts: selectedShifts,
                leavesCount: selectedLeaves.length,
              ),
            ),
            Expanded(
              child: (selectedShifts.isEmpty && selectedLeaves.isEmpty)
                  // Il padding tiene il messaggio centrato SOPRA il FAB.
                  ? Padding(
                      padding: EdgeInsets.only(
                        bottom: AppSizes.fabClearance + insets.bottom,
                      ),
                      child: PlaceholderView(
                        icon: Icons.event_busy_rounded,
                        title: 'Niente in questo giorno',
                        subtitle:
                            'Nessun turno o assenza in questa data.',
                        actionLabel: 'Crea turno',
                        onAction: _openForm,
                      ),
                    )
                  // Prima le assenze (contesto), poi i turni del giorno.
                  : ListView(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        0,
                        AppSpacing.sm,
                        AppSizes.fabClearance + insets.bottom,
                      ),
                      children: [
                        // Nome "vivo" dall'anagrafica se c'è; altrimenti quello
                        // fotografato sul documento (membro rimosso dal locale).
                        for (final leave in selectedLeaves)
                          LeaveDayCard(
                            request: leave,
                            employeeName:
                                staffProvider.byUid(leave.employeeUid)?.name ??
                                (leave.employeeName.isNotEmpty
                                    ? leave.employeeName
                                    : 'Dipendente'),
                          ),
                        for (final shift in selectedShifts)
                          _ShiftCard(
                            shift: shift,
                            employeeName:
                                staffProvider.byUid(shift.employeeUid)?.name ??
                                (shift.employeeName.isNotEmpty
                                    ? shift.employeeName
                                    : 'Dipendente'),
                            // Turno futuro di un membro disattivato O rimosso
                            // dal locale: in entrambi i casi va riassegnato.
                            needsReassign:
                                selectedIsFuture &&
                                (staffProvider
                                        .byUid(shift.employeeUid)
                                        ?.isDisattivato ??
                                    true),
                            onEdit: () => _openForm(existing: shift),
                            onDelete: () => _confirmDelete(shift),
                          ),
                      ],
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

/// Intestazione del giorno selezionato, su UNA riga: a sinistra il giorno
/// ("Oggi", "Domani" o la data — mai tutti e due, niente doppioni), a destra
/// un riepilogo sobrio "3 turni · 12 h · 1 assente". Testo attenuato, zero
/// pillole colorate: l'occhio deve andare alle card, non all'intestazione.
class _DayHeader extends StatelessWidget {
  final DateTime day;
  final List<Shift> shifts;
  final int leavesCount;

  const _DayHeader({
    required this.day,
    required this.shifts,
    required this.leavesCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = DateFormatter.relativeDay(day) ?? DateFormatter.full(day);

    // Ore totali pianificate nel giorno (somma delle durate dei turni).
    final totalMinutes = shifts.fold<int>(
      0,
      (sum, s) => sum + DateFormatter.durationMinutes(s.startTime, s.endTime),
    );
    final parts = <String>[
      if (shifts.isNotEmpty)
        shifts.length == 1 ? '1 turno' : '${shifts.length} turni',
      if (totalMinutes > 0) DateFormatter.minutesLabel(totalMinutes),
      if (leavesCount > 0)
        leavesCount == 1 ? '1 assente' : '$leavesCount assenti',
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
        if (parts.isNotEmpty)
          Text(
            parts.join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// Card di un turno nel giorno selezionato: tap per modificare, menù per
/// modificare/eliminare (niente azioni distruttive "nude" dentro la riga).
class _ShiftCard extends StatelessWidget {
  final Shift shift;
  final String employeeName;

  /// Turno futuro di un dipendente disattivato: mostra "Da riassegnare" (UC5).
  final bool needsReassign;

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ShiftCard({
    required this.shift,
    required this.employeeName,
    required this.onEdit,
    required this.onDelete,
    this.needsReassign = false,
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
                  '${DateFormatter.timeRange(shift.startTime, shift.endTime)}'
                  '${shift.notes != null ? ' · ${shift.notes}' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (needsReassign) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _ReassignChip(),
                ],
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

/// Etichetta di avviso su un turno futuro assegnato a un membro disattivato:
/// il responsabile dovrebbe riassegnarlo (UC5, flusso alternativo).
class _ReassignChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final statusColors = Theme.of(context).statusColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: statusColors.warningContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 14,
            color: statusColors.onWarningContainer,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Da riassegnare',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: statusColors.onWarningContainer,
            ),
          ),
        ],
      ),
    );
  }
}
