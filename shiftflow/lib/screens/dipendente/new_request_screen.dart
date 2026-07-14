import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/leave_request.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_request_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/glass_form_scaffold.dart';
import '../../widgets/loading_filled_button.dart';

/// Form con cui il Dipendente invia una richiesta. Tre tipi:
///  - **Permesso**: un singolo giorno, con orario facoltativo;
///  - **Ferie**: un intervallo di giorni interi (dal / al);
///  - **Cambio turno**: legato a un turno esistente.
/// I campi mostrati cambiano in base al tipo scelto.
class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  String _type = LeaveType.permesso;

  // Cambio turno.
  String? _relatedShiftId;

  // Ferie (dal/al) e Permesso (giorno = _startDate).
  DateTime? _startDate;
  DateTime? _endDate;

  // Permesso: orario facoltativo.
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// TimeOfDay(8, 5) -> "08:05" (padding: le stringhe restano ordinabili).
  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // La fine non può precedere l'inizio: sposta lì la sua data minima.
    final firstDate = isStart ? today : (_startDate ?? today);
    final initial = (isStart ? _startDate : _endDate) ?? _startDate ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate) ? firstDate : initial,
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 365 * 2)),
      helpText: isStart
          ? (_type == LeaveType.ferie ? 'Data inizio' : 'Giorno')
          : 'Data fine',
      cancelText: 'Annulla',
      confirmText: 'OK',
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        // Se la fine è ora precedente all'inizio, la riallineiamo.
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          (isStart ? _startTime : _endTime) ??
          const TimeOfDay(hour: 9, minute: 0),
      helpText: isStart ? 'Ora inizio' : 'Ora fine',
      cancelText: 'Annulla',
      confirmText: 'OK',
    );
    if (picked != null) {
      setState(() => isStart ? _startTime = picked : _endTime = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final provider = context.read<LeaveRequestProvider>();

    // Campi che dipendono dal tipo.
    DateTime? startDate;
    DateTime? endDate;
    String? startTime;
    String? endTime;
    String? relatedShiftId;

    switch (_type) {
      case LeaveType.ferie:
        startDate = _dateOnly(_startDate!);
        endDate = _dateOnly(_endDate!);
      case LeaveType.permesso:
        startDate = _dateOnly(_startDate!);
        endDate = startDate; // un solo giorno
        // L'orario è facoltativo, ma se c'è dev'essere completo (inizio + fine).
        if ((_startTime == null) != (_endTime == null)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Indica sia l\'ora di inizio che quella di fine, '
                'oppure lascia entrambe vuote.',
              ),
            ),
          );
          return;
        }
        startTime = _startTime != null ? _formatTime(_startTime!) : null;
        endTime = _endTime != null ? _formatTime(_endTime!) : null;
      case LeaveType.cambioTurno:
        relatedShiftId = _relatedShiftId;
        // UC3-E2: rete di sicurezza contro i doppioni. Il menù disabilita già i
        // turni con una richiesta in attesa, ma potrebbe essercene comparsa una
        // (es. da un altro dispositivo) dopo l'apertura di questa schermata.
        final hasPending =
            relatedShiftId != null &&
            provider.requests.any(
              (r) =>
                  r.relatedShiftId == relatedShiftId &&
                  r.status == LeaveStatus.inAttesa,
            );
        if (hasPending) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Esiste già una richiesta in attesa per questo turno.',
              ),
            ),
          );
          return;
        }
    }

    final reason = _reasonController.text.trim();
    final request = LeaveRequest(
      id: '',
      employeeUid: user.uid,
      // Nome "fotografato" sulla richiesta: lo storico resta leggibile anche
      // se in futuro il dipendente viene rimosso dall'anagrafica.
      employeeName: user.name,
      type: _type,
      relatedShiftId: relatedShiftId,
      reason: reason.isEmpty ? null : reason,
      status: LeaveStatus.inAttesa,
      startDate: startDate,
      endDate: endDate,
      startTime: startTime,
      endTime: endTime,
    );

    final ok = await provider.createRequest(request);

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Richiesta inviata.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'Errore. Riprova.')),
      );
    }
  }

  /// Spiegazione breve del tipo scelto, mostrata sotto il selettore.
  String get _typeHint => switch (_type) {
    LeaveType.ferie => 'Un periodo di più giorni interi (dal / al).',
    LeaveType.cambioTurno => 'Chiedi di cambiare un turno già assegnato.',
    _ => 'Un solo giorno, con orario facoltativo.',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSaving = context.watch<LeaveRequestProvider>().isSaving;

    return GlassFormScaffold(
      title: 'Nuova richiesta',
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tre opzioni, tre pulsanti in vista: con così poche
            // scelte un menù a tendina le nasconderebbe e basta
            // (regola: rendere visibili le opzioni disponibili).
            Text('Tipo di richiesta', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: LeaveType.permesso,
                  label: Text('Permesso'),
                ),
                ButtonSegment(value: LeaveType.ferie, label: Text('Ferie')),
                ButtonSegment(
                  value: LeaveType.cambioTurno,
                  label: Text('Cambio'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) =>
                  setState(() => _type = selection.first),
            ),
            const SizedBox(height: AppSpacing.xs),
            // Una riga di aiuto che cambia col tipo scelto: spiega
            // cosa aspettarsi prima di compilare (feedback immediato).
            Text(
              _typeHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ..._buildTypeFields(),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _reasonController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Motivo (facoltativo)',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            LoadingFilledButton(
              isLoading: isSaving,
              onPressed: _submit,
              label: 'Invia richiesta',
            ),
          ],
        ),
      ),
    );
  }

  /// I campi specifici del tipo di richiesta selezionato.
  List<Widget> _buildTypeFields() {
    switch (_type) {
      case LeaveType.ferie:
        return [
          _dateField(
            label: 'Dal',
            icon: Icons.calendar_today_rounded,
            value: _startDate,
            onTap: () => _pickDate(isStart: true),
          ),
          const SizedBox(height: AppSpacing.md),
          _dateField(
            label: 'Al',
            icon: Icons.event_rounded,
            value: _endDate,
            onTap: () => _pickDate(isStart: false),
          ),
        ];
      case LeaveType.permesso:
        return [
          _dateField(
            label: 'Giorno',
            icon: Icons.calendar_today_rounded,
            value: _startDate,
            onTap: () => _pickDate(isStart: true),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _timeField(
                  label: 'Dalle (facolt.)',
                  value: _startTime,
                  onTap: () => _pickTime(isStart: true),
                  onClear: () => setState(() => _startTime = null),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _timeField(
                  label: 'Alle (facolt.)',
                  value: _endTime,
                  onTap: () => _pickTime(isStart: false),
                  onClear: () => setState(() => _endTime = null),
                ),
              ),
            ],
          ),
        ];
      case LeaveType.cambioTurno:
        return [_buildShiftDropdown()];
      default:
        return const [];
    }
  }

  /// Campo data readOnly (il valore si sceglie dal date picker).
  /// `key: ValueKey(value)` forza la ricostruzione quando la data cambia,
  /// così l'initialValue si aggiorna.
  Widget _dateField({
    required String label,
    required IconData icon,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return TextFormField(
      key: ValueKey('$label-$value'),
      readOnly: true,
      onTap: onTap,
      initialValue: value == null ? '' : DateFormatter.full(value),
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (_) => value == null ? 'Scegli la data.' : null,
    );
  }

  /// Campo orario readOnly e facoltativo, con pulsante per azzerarlo.
  Widget _timeField({
    required String label,
    required TimeOfDay? value,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return TextFormField(
      key: ValueKey('$label-$value'),
      readOnly: true,
      onTap: onTap,
      initialValue: value == null ? '' : _formatTime(value),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.schedule_rounded),
        suffixIcon: value != null
            ? IconButton(
                tooltip: 'Rimuovi',
                icon: const Icon(Icons.clear_rounded),
                onPressed: onClear,
              )
            : null,
      ),
    );
  }

  /// Menù del turno collegato (solo per il cambio turno). Mostra i turni
  /// futuri; quelli con una richiesta in attesa sono disabilitati (UC3-E2).
  Widget _buildShiftDropdown() {
    final allShifts = context.watch<ShiftProvider>().shifts;
    final requests = context.watch<LeaveRequestProvider>().requests;

    // UC3-E1: nessuna richiesta su un turno già trascorso -> solo da oggi in poi
    // (l'orario non conta: un turno di oggi è ancora valido).
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final futureShifts = allShifts.where((s) {
      final day = DateTime(s.date.year, s.date.month, s.date.day);
      return !day.isBefore(today);
    }).toList();

    // Turni per cui ho già una richiesta in attesa: disabilitati e annotati.
    final pendingShiftIds = requests
        .where(
          (r) => r.status == LeaveStatus.inAttesa && r.relatedShiftId != null,
        )
        .map((r) => r.relatedShiftId!)
        .toSet();

    return DropdownButtonFormField<String>(
      initialValue: _relatedShiftId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Turno interessato',
        prefixIcon: Icon(Icons.event_rounded),
      ),
      items: [
        for (final shift in futureShifts)
          DropdownMenuItem(
            value: shift.id,
            enabled: !pendingShiftIds.contains(shift.id),
            child: Text(
              '${DateFormatter.full(shift.date)} · '
              '${DateFormatter.timeRange(shift.startTime, shift.endTime)}'
              '${pendingShiftIds.contains(shift.id) ? ' · richiesta in attesa' : ''}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (id) => setState(() => _relatedShiftId = id),
      validator: (value) =>
          value == null ? 'Scegli il turno da cambiare.' : null,
    );
  }
}
