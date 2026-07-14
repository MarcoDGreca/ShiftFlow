import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/shift.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_request_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/date_badge.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/info_pill.dart';
import '../../widgets/leave_day_card.dart';
import '../../widgets/next_shift_hero.dart';
import '../../widgets/placeholder_view.dart';
import '../../widgets/section_header.dart';
import '../../widgets/shift_calendar.dart';
import '../../widgets/sync_status_banner.dart';
import 'shift_detail_sheet.dart';

/// Sezione "I miei turni" del Dipendente. Due modi di guardare gli stessi
/// turni (solo i propri, RF3):
/// - **Lista**: il prossimo turno in evidenza (pattern "Up Next" delle app di
///   turni) e sotto i successivi; i passati dietro un filtro;
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
        // Anagrafica del locale: serve solo a tradurre in nomi gli uid dei
        // colleghi mostrati nel dettaglio di un turno (UC2). Le regole
        // consentono a un membro di leggere lo staff del proprio locale.
        context.read<StaffProvider>().listenForRestaurant(user.restaurantId);
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
          lastUpdated: shiftProvider.lastSyncedAt,
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
                icon: Icon(Icons.view_agenda_rounded),
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

  /// Vista "Lista": prossimo turno in evidenza, poi i successivi; i passati
  /// dietro due chip-filtro leggeri (meno ingombranti di un secondo
  /// SegmentedButton impilato).
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

    final showProssimi = _filtro == _Filtro.prossimi;
    final visibili = showProssimi ? prossimi : passati;

    // In "Prossimi" il primo turno diventa la card hero; gli altri seguono.
    final hero = showProssimi && prossimi.isNotEmpty ? prossimi.first : null;
    final rest = hero == null ? visibili : prossimi.sublist(1);

    return Column(
      children: [
        // Filtro Prossimi/Passati come chip: gerarchia più leggera rispetto
        // al selettore di vista qui sopra (che è la scelta principale).
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Prossimi'),
                selected: showProssimi,
                onSelected: (_) =>
                    setState(() => _filtro = _Filtro.prossimi),
              ),
              const SizedBox(width: AppSpacing.sm),
              ChoiceChip(
                label: const Text('Passati'),
                selected: !showProssimi,
                onSelected: (_) => setState(() => _filtro = _Filtro.passati),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: AsyncStateView(
            isLoading: shiftProvider.isLoading,
            errorMessage: shiftProvider.errorMessage,
            isEmpty: visibili.isEmpty,
            emptyIcon: showProssimi
                ? Icons.event_busy_rounded
                : Icons.history_rounded,
            emptyTitle: showProssimi
                ? 'Nessun turno in programma'
                : 'Nessun turno passato',
            emptySubtitle: showProssimi
                ? 'Quando il responsabile ti assegnerà un turno, comparirà qui.'
                : 'Qui troverai lo storico dei tuoi turni.',
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.sm,
                0,
                AppSpacing.sm,
                AppSpacing.md + insets.bottom,
              ),
              children: [
                if (hero != null)
                  NextShiftHero(
                    shift: hero,
                    onTap: () => showShiftDetailSheet(context, hero),
                  ),
                if (hero != null && rest.isNotEmpty)
                  SectionHeader(
                    title: 'In programma',
                    trailing: '${rest.length}',
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.xs,
                    ),
                  ),
                for (final shift in rest)
                  _ShiftCard(
                    shift: shift,
                    onTap: () => showShiftDetailSheet(context, shift),
                  ),
              ],
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

    // "Oggi"/"Domani" AL POSTO della data (mai insieme: sarebbe un doppione;
    // la data completa è già evidenziata sul calendario qui sopra).
    final dayTitle =
        DateFormatter.relativeDay(_selectedDay) ??
        DateFormatter.full(_selectedDay);

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
          child: Text(dayTitle, style: theme.textTheme.titleMedium),
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
                      _ShiftCard(
                        shift: shift,
                        showDate: false,
                        onTap: () => showShiftDetailSheet(context, shift),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Card di un singolo turno (sola lettura). A sinistra un elemento distintivo
/// — il badge con la data in modalità Lista, un'icona orologio nella vista
/// Calendario (dove il giorno è già in evidenza) — poi orario, durata e note.
class _ShiftCard extends StatelessWidget {
  final Shift shift;

  /// Mostra il badge con la data. Nella vista calendario è `false`: il giorno
  /// è già indicato dall'intestazione sopra la lista.
  final bool showDate;

  /// Tocco sulla card: apre il dettaglio del turno (colleghi inclusi, UC2).
  final VoidCallback? onTap;

  const _ShiftCard({required this.shift, this.showDate = true, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final Widget leading = showDate
        ? DateBadge(date: shift.date)
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

    final duration = DateFormatter.durationLabel(
      shift.startTime,
      shift.endTime,
    );

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          leading,
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormatter.timeRange(
                          shift.startTime,
                          shift.endTime,
                        ),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    // La durata risponde a "quanto lavoro?" senza far fare
                    // i conti a mente sull'orario.
                    if (duration != null)
                      InfoPill(icon: Icons.timelapse_rounded, label: duration),
                  ],
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
          const SizedBox(width: AppSpacing.xs),
          Icon(
            Icons.chevron_right_rounded,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}
