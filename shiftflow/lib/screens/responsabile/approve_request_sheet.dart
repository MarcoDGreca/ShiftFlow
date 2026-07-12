import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/app_user.dart';
import '../../models/leave_request.dart';
import '../../models/shift.dart';

/// Esito della scelta del Responsabile su cosa fare del turno collegato quando
/// approva una richiesta (RF6): quale azione e, se riassegna, verso chi.
class ApproveShiftDecision {
  final ShiftResolution resolution;
  final String? reassignToUid;

  const ApproveShiftDecision(this.resolution, {this.reassignToUid});
}

/// Mostra un foglio in cui il Responsabile, approvando una richiesta con un
/// turno collegato, sceglie se lasciarlo invariato, riassegnarlo a un collega
/// o eliminarlo. Ritorna la scelta, oppure `null` se annulla.
///
/// [shift] è il turno interessato; [candidates] sono i dipendenti attivi a cui
/// si può riassegnare (l'autore della richiesta è già escluso).
Future<ApproveShiftDecision?> showApproveShiftSheet(
  BuildContext context, {
  required Shift shift,
  required List<AppUser> candidates,
}) {
  return showModalBottomSheet<ApproveShiftDecision>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ApproveShiftSheet(shift: shift, candidates: candidates),
  );
}

class _ApproveShiftSheet extends StatefulWidget {
  final Shift shift;
  final List<AppUser> candidates;

  const _ApproveShiftSheet({required this.shift, required this.candidates});

  @override
  State<_ApproveShiftSheet> createState() => _ApproveShiftSheetState();
}

class _ApproveShiftSheetState extends State<_ApproveShiftSheet> {
  ShiftResolution _resolution = ShiftResolution.keep;
  String? _reassignToUid;

  bool get _canReassign => widget.candidates.isNotEmpty;

  void _confirm() {
    Navigator.of(context).pop(
      ApproveShiftDecision(
        _resolution,
        reassignToUid: _resolution == ShiftResolution.reassign
            ? _reassignToUid
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shift = widget.shift;

    // Se ha scelto "riassegna" deve anche indicare a chi.
    final missingTarget =
        _resolution == ShiftResolution.reassign && _reassignToUid == null;

    return Padding(
      // Lascia spazio sotto la home indicator (e sopra un'eventuale tastiera).
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Approva la richiesta', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Turno collegato: ${DateFormatter.full(shift.date)} · '
            '${DateFormatter.timeRange(shift.startTime, shift.endTime)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Cosa faccio del turno?', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),

          // Dopo Flutter 3.32 il valore del gruppo si gestisce con RadioGroup,
          // non più con groupValue/onChanged su ogni RadioListTile.
          RadioGroup<ShiftResolution>(
            groupValue: _resolution,
            onChanged: (v) => setState(() => _resolution = v!),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const RadioListTile<ShiftResolution>(
                  value: ShiftResolution.keep,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Lascia invariato'),
                  subtitle: Text('Approva senza modificare il turno.'),
                ),
                // "Riassegna" ha senso solo se c'è almeno un collega attivo.
                if (_canReassign) ...[
                  const RadioListTile<ShiftResolution>(
                    value: ShiftResolution.reassign,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Riassegna a un collega'),
                    subtitle: Text('Il turno passa a un altro dipendente.'),
                  ),
                  // Il menù del destinatario compare solo se "Riassegna" è scelto.
                  if (_resolution == ShiftResolution.reassign)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.xl,
                        bottom: AppSpacing.sm,
                      ),
                      child: DropdownButtonFormField<String>(
                        initialValue: _reassignToUid,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Nuovo assegnatario',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        items: [
                          for (final member in widget.candidates)
                            DropdownMenuItem(
                              value: member.uid,
                              child: Text(member.name),
                            ),
                        ],
                        onChanged: (uid) =>
                            setState(() => _reassignToUid = uid),
                      ),
                    ),
                ],
                const RadioListTile<ShiftResolution>(
                  value: ShiftResolution.remove,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Elimina il turno'),
                  subtitle: Text('Il turno viene rimosso dal calendario.'),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annulla'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: missingTarget ? null : _confirm,
                  child: const Text('Approva'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
