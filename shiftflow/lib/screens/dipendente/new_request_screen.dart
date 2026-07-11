import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/leave_request.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_request_provider.dart';
import '../../providers/shift_provider.dart';

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

    final reason = _reasonController.text.trim();
    final request = LeaveRequest(
      id: '',
      employeeUid: user.uid,
      type: _type,
      relatedShiftId: _relatedShiftId,
      reason: reason.isEmpty ? null : reason,
      status: LeaveStatus.inAttesa,
    );

    final provider = context.read<LeaveRequestProvider>();
    final ok = await provider.createRequest(request);

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Richiesta inviata.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'Errore. Riprova.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shifts = context.watch<ShiftProvider>().shifts;
    final isSaving = context.watch<LeaveRequestProvider>().isSaving;

    // Per un cambio turno indicare il turno è obbligatorio; per un permesso no.
    final shiftRequired = _type == LeaveType.cambioTurno;

    return Scaffold(
      appBar: AppBar(title: const Text('Nuova richiesta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Tipo di richiesta',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: LeaveType.permesso,
                    label: Text('Permesso'),
                    icon: Icon(Icons.beach_access),
                  ),
                  ButtonSegment(
                    value: LeaveType.cambioTurno,
                    label: Text('Cambio turno'),
                    icon: Icon(Icons.swap_horiz),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _relatedShiftId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: shiftRequired
                      ? 'Turno interessato'
                      : 'Turno interessato (facoltativo)',
                  prefixIcon: const Icon(Icons.event),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  if (!shiftRequired)
                    const DropdownMenuItem(value: null, child: Text('Nessuno')),
                  for (final shift in shifts)
                    DropdownMenuItem(
                      value: shift.id,
                      child: Text(
                        '${DateFormatter.full(shift.date)} · '
                        '${shift.startTime}–${shift.endTime}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (id) => setState(() => _relatedShiftId = id),
                validator: (value) => shiftRequired && value == null
                    ? 'Scegli il turno da cambiare.'
                    : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Motivo (facoltativo)',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: isSaving ? null : _submit,
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Invia richiesta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
