import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/leave_request.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_request_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/app_background.dart';
import '../../widgets/glass_container.dart';

/// Form con cui il Dipendente invia una richiesta di permesso o cambio turno.
class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  String _type = LeaveType.permesso;
  String? _relatedShiftId;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    final provider = context.read<LeaveRequestProvider>();

    // UC3-E2: rete di sicurezza contro i doppioni. Il menù disabilita già i
    // turni con una richiesta in attesa, ma una richiesta potrebbe essere
    // comparsa (es. da un altro dispositivo) dopo l'apertura di questa schermata.
    final hasPending =
        _relatedShiftId != null &&
        provider.requests.any(
          (r) =>
              r.relatedShiftId == _relatedShiftId &&
              r.status == LeaveStatus.inAttesa,
        );
    if (hasPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esiste già una richiesta in attesa per questo turno.'),
        ),
      );
      return;
    }

    final reason = _reasonController.text.trim();
    final request = LeaveRequest(
      id: '',
      employeeUid: user.uid,
      type: _type,
      relatedShiftId: _relatedShiftId,
      reason: reason.isEmpty ? null : reason,
      status: LeaveStatus.inAttesa,
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

  @override
  Widget build(BuildContext context) {
    final allShifts = context.watch<ShiftProvider>().shifts;
    final requests = context.watch<LeaveRequestProvider>().requests;
    final isSaving = context.watch<LeaveRequestProvider>().isSaving;
    final theme = Theme.of(context);
    // Con extendBodyBehindAppBar il contenuto parte da sotto la barra; `bottom`
    // tiene il pulsante sopra la barra gesti su schermi piccoli.
    final viewPadding = MediaQuery.paddingOf(context);

    // Per un cambio turno indicare il turno è obbligatorio; per un permesso no.
    final shiftRequired = _type == LeaveType.cambioTurno;

    // UC3-E1: non si richiede nulla su un turno già trascorso -> mostriamo solo
    // i turni da oggi in avanti (l'orario non conta: un turno di oggi è valido).
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final futureShifts = allShifts.where((s) {
      final day = DateTime(s.date.year, s.date.month, s.date.day);
      return !day.isBefore(today);
    }).toList();

    // UC3-E2: turni per cui ho già una richiesta in attesa. Li mostriamo
    // disabilitati, così non se ne può creare una seconda per lo stesso turno.
    final pendingShiftIds = requests
        .where(
          (r) => r.status == LeaveStatus.inAttesa && r.relatedShiftId != null,
        )
        .map((r) => r.relatedShiftId!)
        .toSet();

    // Voci del menù "turno": eventuale "Nessuno" (solo per il permesso), poi i
    // turni futuri; quelli già richiesti sono disabilitati e annotati.
    final shiftItems = <DropdownMenuItem<String>>[
      if (!shiftRequired)
        const DropdownMenuItem(value: null, child: Text('Nessuno')),
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
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Nuova richiesta'),
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
                      Text(
                        'Tipo di richiesta',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: LeaveType.permesso,
                            label: Text('Permesso'),
                            icon: Icon(Icons.beach_access_rounded),
                          ),
                          ButtonSegment(
                            value: LeaveType.cambioTurno,
                            label: Text('Cambio turno'),
                            icon: Icon(Icons.swap_horiz_rounded),
                          ),
                        ],
                        selected: {_type},
                        onSelectionChanged: (s) =>
                            setState(() => _type = s.first),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      DropdownButtonFormField<String>(
                        initialValue: _relatedShiftId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: shiftRequired
                              ? 'Turno interessato'
                              : 'Turno interessato (facoltativo)',
                          prefixIcon: const Icon(Icons.event_rounded),
                        ),
                        items: shiftItems,
                        onChanged: (id) => setState(() => _relatedShiftId = id),
                        validator: (value) => shiftRequired && value == null
                            ? 'Scegli il turno da cambiare.'
                            : null,
                      ),
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
                            : const Text('Invia richiesta'),
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
