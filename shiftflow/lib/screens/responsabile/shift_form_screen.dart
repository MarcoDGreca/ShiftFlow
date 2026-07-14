import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/dialogs.dart';
import '../../models/shift.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_request_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/glass_form_scaffold.dart';
import '../../widgets/loading_filled_button.dart';
import '../../widgets/section_header.dart';

/// Form di creazione/modifica di un turno.
///
/// In **creazione** i giorni si scelgono direttamente su un mini-calendario
/// multi-selezione: tocchi le date in cui il turno vale (anche sparse, anche
/// su mesi diversi) e nasce un turno per ciascuna, tutte in un unico batch
/// atomico. In **modifica** si lavora sul singolo turno esistente (campi
/// precompilati, una sola data). [initialDate] pre-seleziona il giorno da cui
/// si è partiti sul calendario della home.
class ShiftFormScreen extends StatefulWidget {
  final Shift? existing;
  final DateTime? initialDate;

  const ShiftFormScreen({super.key, this.existing, this.initialDate});

  @override
  State<ShiftFormScreen> createState() => _ShiftFormScreenState();
}

class _ShiftFormScreenState extends State<ShiftFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  String? _employeeUid;
  TimeOfDay? _start;
  TimeOfDay? _end;

  /// I giorni scelti sul mini-calendario (solo creazione), normalizzati a
  /// mezzanotte. Un turno per ciascuno.
  final Set<DateTime> _selectedDays = {};

  /// Il mese mostrato dal mini-calendario.
  late DateTime _focusedDay = widget.initialDate ?? DateTime.now();

  /// La data del turno in MODIFICA (in creazione si usa [_selectedDays]).
  DateTime? _date;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _employeeUid = existing.employeeUid;
      _date = existing.date;
      _start = _parseTime(existing.startTime);
      _end = _parseTime(existing.endTime);
      _notesController.text = existing.notes ?? '';
    } else if (widget.initialDate != null) {
      // Turno nuovo dal calendario della home: quel giorno parte già scelto.
      _selectedDays.add(_dateOnly(widget.initialDate!));
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// "18:30" -> TimeOfDay(18, 30). `null` se la stringa non è valida.
  TimeOfDay? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// TimeOfDay(8, 5) -> "08:05" (il padding tiene ordinabili le stringhe).
  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          (isStart ? _start : _end) ?? const TimeOfDay(hour: 18, minute: 0),
    );
    if (picked != null) {
      setState(() => isStart ? _start = picked : _end = picked);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Aggiunge o toglie un giorno dalla selezione (tocco sul mini-calendario).
  void _toggleDay(DateTime day) {
    final normalized = _dateOnly(day);
    setState(() {
      if (!_selectedDays.remove(normalized)) _selectedDays.add(normalized);
    });
  }

  /// I giorni scelti in ordine cronologico (il Set non ha un ordine suo).
  List<DateTime> get _sortedDays => _selectedDays.toList()..sort();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    // I turni a cavallo di mezzanotte sono ammessi (es. 22:00→02:00 = finisce
    // il giorno dopo). L'unico caso senza senso è inizio = fine (durata zero).
    final startMinutes = _start!.hour * 60 + _start!.minute;
    final endMinutes = _end!.hour * 60 + _end!.minute;
    if (endMinutes == startMinutes) {
      _showSnack("L'ora di fine non può essere uguale all'inizio.");
      return;
    }

    if (!_isEditing && _selectedDays.isEmpty) {
      _showSnack('Tocca sul calendario i giorni in cui vale il turno.');
      return;
    }

    // UC1-E4: il destinatario potrebbe essere stato disattivato dopo l'apertura
    // della schermata (lo stato dello staff è in ascolto in tempo reale).
    // Blocchiamo solo una vera ASSEGNAZIONE — turno nuovo o assegnatario
    // cambiato — a un membro disattivato; modificare un turno già suo è ammesso.
    final assignee = context.read<StaffProvider>().byUid(_employeeUid!);
    final isNewAssignment =
        !_isEditing || _employeeUid != widget.existing!.employeeUid;
    if (isNewAssignment && (assignee?.isDisattivato ?? false)) {
      _showSnack('Questo dipendente è stato disattivato: scegline un altro.');
      return;
    }

    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;

    final leaveProvider = context.read<LeaveRequestProvider>();
    final provider = context.read<ShiftProvider>();

    final notes = _notesController.text.trim();
    final shift = Shift(
      id: widget.existing?.id ?? '',
      employeeUid: _employeeUid!,
      // Nome "fotografato" sul documento: sopravvive alla rimozione del
      // dipendente dall'anagrafica (lo storico resta leggibile).
      employeeName: assignee?.name ?? widget.existing?.employeeName ?? '',
      // In creazione è un segnaposto: ogni turno avrà poi il proprio giorno.
      date: _date ?? _sortedDays.first,
      startTime: _formatTime(_start!),
      endTime: _formatTime(_end!),
      notes: notes.isEmpty ? null : notes,
      // In modifica preserviamo autore e data di creazione originali.
      createdBy: widget.existing?.createdBy ?? currentUser.uid,
      createdAt: widget.existing?.createdAt,
    );

    // --- Modifica di un turno esistente: percorso semplice, una sola data.
    if (_isEditing) {
      if (leaveProvider.isOnLeave(shift.employeeUid, shift.date)) {
        _showSnack(
          'Il dipendente è assente in quel giorno (ferie o permesso).',
        );
        return;
      }
      // Segnalazione sovrapposizione (§7.3): avvisa, la scelta resta al
      // responsabile.
      final overlap = await provider.findOverlap(shift);
      if (!mounted) return;
      if (overlap != null) {
        final proceed = await _confirmOverlap(overlap);
        if (!proceed || !mounted) return;
      }
      final ok = await provider.updateShift(shift);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop();
      } else {
        _showSnack(provider.errorMessage ?? 'Errore. Riprova.');
      }
      return;
    }

    // --- Creazione: un turno per ogni giorno scelto sul calendario. ---
    // I giorni in cui il dipendente è assente (ferie/permesso approvati)
    // vengono saltati, non creati: verranno segnalati alla fine.
    final toCreate = <Shift>[];
    final skipped = <DateTime>[];
    for (final day in _sortedDays) {
      if (leaveProvider.isOnLeave(shift.employeeUid, day)) {
        skipped.add(day);
      } else {
        toCreate.add(shift.copyWithDate(day));
      }
    }

    if (toCreate.isEmpty) {
      _showSnack(
        'Il dipendente è assente in tutte le date scelte: nessun turno creato.',
      );
      return;
    }

    // Sovrapposizioni (§7.3): raccogliamo le date in conflitto e avvisiamo
    // una volta sola; la decisione resta al responsabile.
    final overlapDays = <DateTime>[];
    Shift? firstOverlap;
    for (final s in toCreate) {
      final overlap = await provider.findOverlap(s);
      if (overlap != null) {
        overlapDays.add(s.date);
        firstOverlap ??= overlap;
      }
    }
    if (!mounted) return;
    if (overlapDays.isNotEmpty) {
      final bool proceed;
      if (overlapDays.length == 1 && toCreate.length == 1) {
        // Caso singolo: messaggio dettagliato di sempre.
        proceed = await _confirmOverlap(firstOverlap!);
      } else {
        proceed = await showAppConfirmDialog(
          context,
          title: 'Turni sovrapposti',
          message:
              'Il dipendente ha già turni che si sovrappongono nei '
              'giorni: ${overlapDays.map(DateFormatter.dayMonthShort).join(', ')}.'
              '\n\nVuoi salvare comunque?',
          confirmLabel: 'Salva comunque',
          cancelLabel: 'No',
        );
      }
      if (!proceed || !mounted) return;
    }

    final ok = toCreate.length == 1
        ? await provider.createShift(toCreate.first)
        : await provider.createShifts(toCreate);

    if (!mounted) return;
    if (!ok) {
      _showSnack(provider.errorMessage ?? 'Errore. Riprova.');
      return;
    }
    Navigator.of(context).pop();
    // Feedback sul risultato: quanti turni creati e quali giorni saltati.
    final parts = <String>[
      toCreate.length == 1 ? 'Turno creato' : '${toCreate.length} turni creati',
      if (skipped.isNotEmpty)
        'saltat${skipped.length == 1 ? 'o' : 'i'} '
            '${skipped.map(DateFormatter.dayMonthShort).join(', ')} (assente)',
    ];
    _showSnack('${parts.join(' · ')}.');
  }

  /// Chiede conferma quando il nuovo turno si sovrappone a un altro dello
  /// stesso dipendente (§7.3).
  Future<bool> _confirmOverlap(Shift other) {
    return showAppConfirmDialog(
      context,
      title: 'Turni sovrapposti',
      message:
          'Il dipendente ha già un turno che si sovrappone:\n'
          '${DateFormatter.full(other.date)} · '
          '${other.startTime}–${other.endTime}.\n\n'
          'Vuoi salvarlo comunque?',
      confirmLabel: 'Salva comunque',
      cancelLabel: 'No',
    );
  }

  /// Annotazione per la voce del dipendente nel menù: segnala se è assente
  /// in tutti o in parte dei giorni scelti. Restituisce anche se la voce va
  /// disabilitata (assente ovunque: non avrebbe senso sceglierlo).
  (String suffix, bool enabled) _availability(String uid) {
    final days = _isEditing
        ? [if (_date != null) _dateOnly(_date!)]
        : _sortedDays;
    if (days.isEmpty) return ('', true);
    final leaveProvider = context.read<LeaveRequestProvider>();
    final absent = days.where((d) => leaveProvider.isOnLeave(uid, d)).length;
    if (absent == 0) return ('', true);
    if (absent == days.length) {
      return (
        days.length == 1 ? ' (assente)' : ' (assente nelle date scelte)',
        false,
      );
    }
    return (' (assente in alcuni giorni)', true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final staff = context.watch<StaffProvider>().staff;
    final isSaving = context.watch<ShiftProvider>().isSaving;
    // Il watch fa ridisegnare il form quando cambiano le assenze approvate
    // (usate da _availability e dai salti in salvataggio).
    context.watch<LeaveRequestProvider>();

    // Ai nuovi turni si assegnano solo dipendenti attivi; se stiamo MODIFICANDO
    // un turno di qualcuno nel frattempo disattivato, lo teniamo comunque
    // selezionabile per non perderne l'assegnazione.
    final selectable = staff
        .where((m) => m.isAttivo || m.uid == _employeeUid)
        .toList();

    // Difensivo: se il turno è di qualcuno non più in anagrafica, il valore
    // non comparirebbe tra le voci del dropdown e Flutter andrebbe in errore.
    final employeeValue = selectable.any((m) => m.uid == _employeeUid)
        ? _employeeUid
        : null;
    // Membro sparito dall'anagrafica mentre il form era aperto: azzeriamo la
    // scelta, così la validazione chiede di sceglierne un altro invece di
    // salvare un turno intestato a un uid rimosso. (Solo a staff caricato:
    // una lista ancora vuota non significa "membro sparito".)
    if (staff.isNotEmpty && employeeValue == null) _employeeUid = null;

    final count = _selectedDays.length;

    return GlassFormScaffold(
      title: _isEditing ? 'Modifica turno' : 'Nuovo turno',
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              title: 'Turno',
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
            ),
            DropdownButtonFormField<String>(
              // La chiave segue il valore: se il membro selezionato sparisce
              // dalle voci, il campo si ricostruisce azzerato invece di
              // tenere in pancia un valore che non esiste più (errore Flutter).
              key: ValueKey('employee-$employeeValue'),
              initialValue: employeeValue,
              // Senza isExpanded un nome lungo + annotazione
              // "(assente...)" sborda dal campo.
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Dipendente',
                prefixIcon: Icon(Icons.person_outline),
              ),
              items: [
                for (final member in selectable)
                  // Voce annotata (ed eventualmente disabilitata)
                  // se il membro è assente nei giorni scelti:
                  // si vede subito il PERCHÉ non è assegnabile.
                  _memberItem(
                    member.uid,
                    member.name,
                    disattivato: member.isDisattivato,
                  ),
              ],
              onChanged: (uid) => setState(() => _employeeUid = uid),
              validator: (_) =>
                  _employeeUid == null ? 'Scegli un dipendente.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              // Allineati in alto: se solo uno dei due campi mostra
              // l'errore di validazione, l'altro non scivola giù.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('start-$_start'),
                    readOnly: true,
                    onTap: () => _pickTime(isStart: true),
                    initialValue: _start == null ? '' : _formatTime(_start!),
                    decoration: const InputDecoration(
                      labelText: 'Inizio',
                      prefixIcon: Icon(Icons.schedule_rounded),
                    ),
                    validator: (_) => _start == null ? 'Ora di inizio.' : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('end-$_end'),
                    readOnly: true,
                    onTap: () => _pickTime(isStart: false),
                    initialValue: _end == null ? '' : _formatTime(_end!),
                    decoration: const InputDecoration(
                      labelText: 'Fine',
                      prefixIcon: Icon(Icons.schedule_rounded),
                    ),
                    validator: (_) => _end == null ? 'Ora di fine.' : null,
                  ),
                ),
              ],
            ),

            // --- Giorni ---
            if (_isEditing) ...[
              // In modifica il turno è uno solo: campo data classico.
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: ValueKey(_date),
                readOnly: true,
                onTap: _pickDate,
                initialValue: _date == null ? '' : DateFormatter.full(_date!),
                decoration: const InputDecoration(
                  labelText: 'Data',
                  prefixIcon: Icon(Icons.calendar_today_rounded),
                ),
                validator: (_) => _date == null ? 'Scegli la data.' : null,
              ),
            ] else ...[
              SectionHeader(
                title: 'Giorni',
                trailing: count == 0
                    ? null
                    : count == 1
                    ? '1 giorno'
                    : '$count giorni',
                padding: const EdgeInsets.fromLTRB(
                  0,
                  AppSpacing.lg,
                  0,
                  AppSpacing.sm,
                ),
              ),
              // Mini-calendario multi-selezione: si toccano
              // direttamente i giorni in cui il turno vale, anche
              // sparsi e su mesi diversi. Ritoccare = deselezionare.
              _MultiDayCalendar(
                focusedDay: _focusedDay,
                selectedDays: _selectedDays,
                onDayToggled: _toggleDay,
                onPageChanged: (focused) => _focusedDay = focused,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (count == 0)
                Text(
                  'Tocca i giorni in cui vale il turno.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                // Riepilogo rimovibile: ogni chip è un giorno; la X
                // lo toglie senza dover tornare al mese giusto.
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final day in _sortedDays)
                      InputChip(
                        label: Text(DateFormatter.dayMonthShort(day)),
                        visualDensity: VisualDensity.compact,
                        onDeleted: () => _toggleDay(day),
                      ),
                  ],
                ),
            ],

            const SectionHeader(
              title: 'Note',
              padding: EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.sm),
            ),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (facoltative)',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            LoadingFilledButton(
              isLoading: isSaving,
              onPressed: _submit,
              label: _isEditing
                  ? 'Salva modifiche'
                  : count > 1
                  ? 'Crea $count turni'
                  : 'Crea turno',
            ),
          ],
        ),
      ),
    );
  }

  /// Voce del menù dipendente con l'annotazione di disponibilità.
  DropdownMenuItem<String> _memberItem(
    String uid,
    String name, {
    required bool disattivato,
  }) {
    final (suffix, available) = _availability(uid);
    return DropdownMenuItem(
      value: uid,
      enabled: available,
      child: Text(
        disattivato ? '$name (disattivato)' : '$name$suffix',
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Mini-calendario mensile con selezione MULTIPLA dei giorni: un tocco
/// seleziona, un altro deseleziona. Stessi codici visivi del calendario
/// della home (oggi cerchiato, selezionato pieno), in formato compatto da
/// dentro-form.
class _MultiDayCalendar extends StatelessWidget {
  final DateTime focusedDay;
  final Set<DateTime> selectedDays;
  final ValueChanged<DateTime> onDayToggled;
  final ValueChanged<DateTime> onPageChanged;

  const _MultiDayCalendar({
    required this.focusedDay,
    required this.selectedDays,
    required this.onDayToggled,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      child: TableCalendar<void>(
        // Stesso intervallo del calendario della home: se il form si apre da
        // un giorno lontano, il focusedDay deve comunque cadere nei limiti.
        firstDay: now.subtract(const Duration(days: 365 * 2)),
        lastDay: now.add(const Duration(days: 365 * 2)),
        focusedDay: focusedDay,
        onPageChanged: onPageChanged,
        startingDayOfWeek: StartingDayOfWeek.monday,
        availableCalendarFormats: const {CalendarFormat.month: 'Mese'},
        // Il calendario vive dentro un form scrollabile: si tiene solo lo
        // swipe orizzontale (cambio mese), il trascinamento verticale deve
        // far scorrere la pagina, non essere inghiottito dal calendario.
        availableGestures: AvailableGestures.horizontalSwipe,
        rowHeight: 44,
        // L'altezza di default (16) taglia le lettere dei giorni.
        daysOfWeekHeight: 24,
        // Multi-selezione: "selezionato" è qualunque giorno nel Set; il tocco
        // commuta (il genitore aggiorna il Set e ricostruisce).
        selectedDayPredicate: (day) =>
            selectedDays.any((d) => isSameDay(d, day)),
        onDaySelected: (selected, _) => onDayToggled(selected),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextFormatter: (date, _) => DateFormatter.monthYear(date),
          titleTextStyle: theme.textTheme.titleSmall!,
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
          weekdayStyle: theme.textTheme.labelSmall!.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          weekendStyle: theme.textTheme.labelSmall!.copyWith(
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
    );
  }
}
