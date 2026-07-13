import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/shift.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_request_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/leave_day_card.dart';
import '../../widgets/placeholder_view.dart';
import '../../widgets/shift_calendar.dart';
import '../../widgets/sync_status_banner.dart';

/// Sezione "I miei turni" del Dipendente. Due modi di guardare gli stessi
/// turni (solo i propri, RF9):
/// - **Lista**: elenco con filtro Prossimi/Passati (storico incluso);
/// - **Calendario**: griglia mensile con i pallini dei propri turni e, sotto,
///   l'elenco del giorno scelto.
class TurniTab extends StatefulWidget {
  const TurniTab({super.key});

  @override
  State<TurniTab> createState() => _TurniTabState();
}

/// Le due modalità di visualizzazione dei turni.
enum _ViewMode { lista, calendario }

/// I due sottoinsiemi dell'elenco in modalità Lista.
enum _Filtro { prossimi, passati }

class _TurniTabState extends State<TurniTab> {
  _ViewMode _view = _ViewMode.lista;
  _Filtro _filtro = _Filtro.prossimi;

  /// Stato del calendario: mese in vista e giorno selezionato.
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    // A fine frame: il provider fa notifyListeners() subito, e farlo durante
    // la costruzione del widget non è permesso.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) {
        // Sottoscrizioni ai SOLI dati di questo dipendente: turni e assenze
        // (queste ultime per i marker e il dettaglio del giorno sul calendario).
        context.read<ShiftProvider>().listenForEmployee(
          user.restaurantId,
          user.uid,
        );
        context.read<LeaveRequestProvider>().listenForEmployee(
          user.restaurantId,
          user.uid,
        );
      }
    });
  }

  /// Un turno è "passato" se il suo giorno è precedente a oggi (l'orario non
  /// conta: un turno di stasera resta tra i "prossimi" per tutta la giornata).
  bool _isPast(Shift shift, DateTime today) {
    final day = DateTime(shift.date.year, shift.date.month, shift.date.day);
    return day.isBefore(today);
  }

  @override
  Widget build(BuildContext context) {
    final shiftProvider = context.watch<ShiftProvider>();
    final leaveProvider = context.watch<LeaveRequestProvider>();
    // Le barre della home sono trasparenti: il contenuto fisso (banner e
    // interruttori) deve partire sotto la AppBar, e le liste finire oltre la
    // NavigationBar.
    final insets = MediaQuery.paddingOf(context);

    return Column(
      children: [
        SizedBox(height: insets.top),
        SyncStatusBanner(
          isFromCache: shiftProvider.isFromCache,
          hasPendingWrites: shiftProvider.hasPendingWrites,
        ),
        // Interruttore Lista / Calendario: stesso dato, due viste.
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: SegmentedButton<_ViewMode>(
            segments: const [
              ButtonSegment(
                value: _ViewMode.lista,
                label: Text('Lista'),
                icon: Icon(Icons.view_list_rounded),
              ),
              ButtonSegment(
                value: _ViewMode.calendario,
                label: Text('Calendario'),
                icon: Icon(Icons.calendar_month_rounded),
              ),
            ],
            selected: {_view},
            onSelectionChanged: (selection) =>
                setState(() => _view = selection.first),
          ),
        ),
        Expanded(
          child: _view == _ViewMode.lista
              ? _buildList(shiftProvider, insets)
              : _buildCalendar(shiftProvider, leaveProvider, insets),
        ),
      ],
    );
  }

  /// Vista "Lista": filtro Prossimi/Passati e card con badge data.
  Widget _buildList(ShiftProvider shiftProvider, EdgeInsets insets) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Partiamo dalla lista già ordinata (data, poi orario) dal provider.
    final prossimi = shiftProvider.shifts
        .where((s) => !_isPast(s, today))
        .toList();
    // I passati li mostriamo dal più recente al più vecchio.
    final passati = shiftProvider.shifts
        .where((s) => _isPast(s, today))
        .toList()
        .reversed
        .toList();

    final visibili = _filtro == _Filtro.prossimi ? prossimi : passati;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: SegmentedButton<_Filtro>(
            segments: const [
              ButtonSegment(
                value: _Filtro.prossimi,
                label: Text('Prossimi'),
                icon: Icon(Icons.upcoming_outlined),
              ),
              ButtonSegment(
                value: _Filtro.passati,
                label: Text('Passati'),
                icon: Icon(Icons.history_rounded),
              ),
            ],
            selected: {_filtro},
            onSelectionChanged: (selection) =>
                setState(() => _filtro = selection.first),
          ),
        ),
        Expanded(
          child: AsyncStateView(
            isLoading: shiftProvider.isLoading,
            errorMessage: shiftProvider.errorMessage,
            isEmpty: visibili.isEmpty,
            emptyIcon: Icons.event_busy_rounded,
            emptyTitle: _filtro == _Filtro.prossimi
                ? 'Nessun turno in programma'
                : 'Nessun turno passato',
            emptySubtitle: _filtro == _Filtro.prossimi
                ? 'Quando il responsabile ti assegnerà un turno, comparirà qui.'
                : 'Qui troverai lo storico dei tuoi turni.',
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.sm,
                0,
                AppSpacing.sm,
                AppSpacing.md + insets.bottom,
              ),
              itemCount: visibili.length,
              itemBuilder: (context, i) => _ShiftCard(shift: visibili[i]),
            ),
          ),
        ),
      ],
    );
  }

  /// Vista "Calendario": mese con i propri turni/assenze e, sotto, il giorno
  /// scelto (prima le assenze, poi i turni).
  Widget _buildCalendar(
    ShiftProvider shiftProvider,
    LeaveRequestProvider leaveProvider,
    EdgeInsets insets,
  ) {
    if (shiftProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (shiftProvider.errorMessage != null && shiftProvider.shifts.isEmpty) {
      return PlaceholderView(
        icon: Icons.error_outline_rounded,
        title: 'Qualcosa è andato storto',
        subtitle: shiftProvider.errorMessage!,
      );
    }

    final theme = Theme.of(context);
    final selectedShifts = shiftProvider.shiftsOn(_selectedDay);
    final selectedLeaves = leaveProvider.approvedLeavesOn(_selectedDay);
    final isEmpty = selectedShifts.isEmpty && selectedLeaves.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          child: isEmpty
              ? const PlaceholderView(
                  icon: Icons.event_available_rounded,
                  title: 'Niente in questo giorno',
                  subtitle: 'Scegli un altro giorno sul calendario.',
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    0,
                    AppSpacing.sm,
                    AppSpacing.md + insets.bottom,
                  ),
                  children: [
                    for (final leave in selectedLeaves)
                      LeaveDayCard(request: leave),
                    for (final shift in selectedShifts)
                      _ShiftCard(shift: shift, showDate: false),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Card di un singolo turno (sola lettura). A sinistra un elemento distintivo
/// — il badge con la data in modalità Lista, un'icona orologio nella vista
/// Calendario (dove il giorno è già in evidenza) — poi orario e note.
class _ShiftCard extends StatelessWidget {
  final Shift shift;

  /// Mostra il badge con la data. Nella vista calendario è `false`: il giorno
  /// è già indicato dall'intestazione sopra la lista.
  final bool showDate;

  const _ShiftCard({required this.shift, this.showDate = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final Widget leading = showDate
        ? _DateBadge(date: shift.date)
        : Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: 0.10),
            ),
            child: Icon(Icons.schedule_rounded, color: scheme.primary),
          );

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          leading,
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormatter.timeRange(shift.startTime, shift.endTime),
                  style: theme.textTheme.titleMedium,
                ),
                if (shift.notes != null && shift.notes!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.notes_rounded,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          shift.notes!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Piccolo blocco data (giorno della settimana, numero, mese) usato come
/// elemento a sinistra delle card in modalità Lista.
class _DateBadge extends StatelessWidget {
  final DateTime date;

  const _DateBadge({required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormatter.weekdayShort(date).toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
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
