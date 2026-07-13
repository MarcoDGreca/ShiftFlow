import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/dialogs.dart';
import '../../models/shift.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_request_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/app_background.dart';
import '../../widgets/glass_container.dart';

/// Form di creazione/modifica di un turno.
///
/// Se [existing] è `null` crea un nuovo turno, altrimenti modifica quello
/// passato (campi precompilati). [initialDate] pre-compila la data di un
/// turno nuovo (es. il giorno selezionato sul calendario). In creazione il
/// turno può essere **ripetuto ogni settimana** (stesso giorno e orario) per
/// un numero di settimane a scelta: i turni nascono in un unico batch atomico.
/// Al salvataggio chiama [ShiftProvider] e, se l'operazione riesce, torna alla
/// lista: le card compariranno o si aggiorneranno da sole grazie allo stream.
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
  DateTime? _date;
  TimeOfDay? _start;
  TimeOfDay? _end;

  /// Quante settimane consecutive coprire: 1 = solo questa (non ripetere).
  int _repeatWeeks = 1;

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
      // Turno nuovo dal calendario: data già impostata al giorno selezionato
      // (normalizzata a mezzanotte: dell'orario si occupano Inizio/Fine).
      final d = widget.initialDate!;
      _date = DateTime(d.year, d.month, d.day);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

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
      date: _date!,
      startTime: _formatTime(_start!),
      endTime: _formatTime(_end!),
      notes: notes.isEmpty ? null : notes,
      // In modifica preserviamo autore e data di creazione originali.
      createdBy: widget.existing?.createdBy ?? currentUser.uid,
      createdAt: widget.existing?.createdAt,
    );

    // --- Modifica di un turno esistente: percorso semplice, senza ripetizioni.
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

    // --- Creazione, eventualmente ripetuta ogni settimana. ---
    // Le occorrenze nei giorni in cui il dipendente è assente (ferie/permesso
    // approvati) vengono saltate, non create: verranno segnalate alla fine.
    final toCreate = <Shift>[];
    final skipped = <DateTime>[];
    for (var week = 0; week < _repeatWeeks; week++) {
      final day = _date!.add(Duration(days: 7 * week));
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

  @override
  Widget build(BuildContext context) {
    final staff = context.watch<StaffProvider>().staff;
    final isSaving = context.watch<ShiftProvider>().isSaving;
    final leaveProvider = context.watch<LeaveRequestProvider>();

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

    // Con extendBodyBehindAppBar il contenuto parte da sotto la barra; `bottom`
    // tiene il pulsante sopra la barra gesti su schermi piccoli.
    final viewPadding = MediaQuery.paddingOf(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifica turno' : 'Nuovo turno'),
        flexibleSpace: const GlassBarBackground(),
      ),
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              viewPadding.top + AppSpacing.lg,
              AppSpacing.lg,
              viewPadding.bottom + AppSpacing.lg,
            ),
            child: ConstrainedBox(
              // Su schermi larghi (tablet) il form non si allarga a nastro.
              constraints: const BoxConstraints(maxWidth: 420),
              child: GlassContainer(
                blur: true,
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.xl),
                ),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: employeeValue,
                        decoration: const InputDecoration(
                          labelText: 'Dipendente',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        items: [
                          for (final member in selectable)
                            // Chi è assente nel giorno scelto (ferie/permesso
                            // approvati) non è assegnabile: voce disabilitata
                            // e annotata, così si vede il PERCHÉ.
                            DropdownMenuItem(
                              value: member.uid,
                              enabled:
                                  _date == null ||
                                  !leaveProvider.isOnLeave(member.uid, _date!),
                              child: Text(
                                member.isDisattivato
                                    ? '${member.name} (disattivato)'
                                    : (_date != null &&
                                          leaveProvider.isOnLeave(
                                            member.uid,
                                            _date!,
                                          ))
                                    ? '${member.name} (assente)'
                                    : member.name,
                              ),
                            ),
                        ],
                        onChanged: (uid) => setState(() => _employeeUid = uid),
                        validator: (_) => _employeeUid == null
                            ? 'Scegli un dipendente.'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // Campo data: readOnly, il valore si sceglie dal date picker.
                      // `key: ValueKey(_date)` forza la ricostruzione del campo quando
                      // la data cambia, così l'initialValue si aggiorna.
                      TextFormField(
                        key: ValueKey(_date),
                        readOnly: true,
                        onTap: _pickDate,
                        initialValue: _date == null
                            ? ''
                            : DateFormatter.full(_date!),
                        decoration: const InputDecoration(
                          labelText: 'Data',
                          prefixIcon: Icon(Icons.calendar_today_rounded),
                        ),
                        validator: (_) =>
                            _date == null ? 'Scegli la data.' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: ValueKey('start-$_start'),
                              readOnly: true,
                              onTap: () => _pickTime(isStart: true),
                              initialValue: _start == null
                                  ? ''
                                  : _formatTime(_start!),
                              decoration: const InputDecoration(
                                labelText: 'Inizio',
                                prefixIcon: Icon(Icons.schedule_rounded),
                              ),
                              validator: (_) =>
                                  _start == null ? 'Ora di inizio.' : null,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: TextFormField(
                              key: ValueKey('end-$_end'),
                              readOnly: true,
                              onTap: () => _pickTime(isStart: false),
                              initialValue: _end == null
                                  ? ''
                                  : _formatTime(_end!),
                              decoration: const InputDecoration(
                                labelText: 'Fine',
                                prefixIcon: Icon(Icons.schedule_rounded),
                              ),
                              validator: (_) =>
                                  _end == null ? 'Ora di fine.' : null,
                            ),
                          ),
                        ],
                      ),
                      // Ripetizione settimanale: solo in creazione (modificare
                      // una serie già creata è fuori portata: si modificano i
                      // singoli turni).
                      if (!_isEditing) ...[
                        const SizedBox(height: AppSpacing.md),
                        DropdownButtonFormField<int>(
                          initialValue: _repeatWeeks,
                          decoration: const InputDecoration(
                            labelText: 'Ripeti ogni settimana',
                            prefixIcon: Icon(Icons.repeat_rounded),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 1,
                              child: Text('Non ripetere'),
                            ),
                            for (var weeks = 2; weeks <= 8; weeks++)
                              DropdownMenuItem(
                                value: weeks,
                                child: Text('Per $weeks settimane'),
                              ),
                          ],
                          onChanged: (weeks) =>
                              setState(() => _repeatWeeks = weeks ?? 1),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
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
                      FilledButton(
                        onPressed: isSaving ? null : _submit,
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _isEditing
                                    ? 'Salva modifiche'
                                    : _repeatWeeks > 1
                                    ? 'Crea $_repeatWeeks turni'
                                    : 'Crea turno',
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
