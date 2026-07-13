import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_status_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/dialogs.dart';
import '../../models/leave_request.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_request_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/staff_provider.dart';
import '../../services/shift_service.dart';
import '../../widgets/requests_list_view.dart';
import 'approve_request_sheet.dart';

/// Sezione "Richieste" del Responsabile: coda di tutte le richieste del locale.
/// Su quelle in attesa mostra i pulsanti Approva/Rifiuta; le altre mostrano
/// solo l'esito (badge). Classe con nome distinto da quella del Dipendente.
class RichiesteResponsabileTab extends StatefulWidget {
  const RichiesteResponsabileTab({super.key});

  @override
  State<RichiesteResponsabileTab> createState() =>
      _RichiesteResponsabileTabState();
}

class _RichiesteResponsabileTabState extends State<RichiesteResponsabileTab> {
  @override
  void initState() {
    super.initState();
    // A fine frame: il provider fa notifyListeners() subito, e farlo durante
    // la costruzione del widget non è permesso.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) {
        final rid = user.restaurantId;
        // Sottoscrizioni idempotenti: richieste + staff (nomi) + turni (dettaglio).
        context.read<LeaveRequestProvider>().listenForRestaurant(rid);
        context.read<StaffProvider>().listenForRestaurant(rid);
        context.read<ShiftProvider>().listenForRestaurant(rid);
      }
    });
  }

  Future<void> _resolve(LeaveRequest request, {required bool approved}) async {
    var shiftResolution = ShiftResolution.keep;
    String? reassignToUid;

    final shiftProvider = context.read<ShiftProvider>();
    final leaveProvider = context.read<LeaveRequestProvider>();
    final staffProvider = context.read<StaffProvider>();

    // Approvando ferie/permesso, i turni del dipendente nel periodo vengono
    // eliminati insieme all'approvazione (stessa transazione). Prima però lo
    // diciamo chiaramente: niente cancellazioni "a sorpresa".
    var removeShiftIds = const <String>[];
    if (approved &&
        (request.isFerie || request.isPermesso) &&
        request.startDate != null &&
        request.endDate != null) {
      final affected = shiftProvider.shiftsForEmployeeInRange(
        request.employeeUid,
        request.startDate!,
        request.endDate!,
      );
      // Permesso con orario: si eliminano solo i turni che si sovrappongono
      // alla fascia richiesta (un permesso di 2 ore non tocca il turno serale).
      final toRemove =
          (request.isPermesso &&
              request.startTime != null &&
              request.endTime != null)
          ? affected
                .where(
                  (s) => ShiftService.timesOverlap(
                    s.startTime,
                    s.endTime,
                    request.startTime!,
                    request.endTime!,
                  ),
                )
                .toList()
          : affected;
      if (toRemove.isNotEmpty) {
        final elenco = toRemove
            .map(
              (s) =>
                  '• ${DateFormatter.dayMonthShort(s.date)} · '
                  '${DateFormatter.timeRange(s.startTime, s.endTime)}',
            )
            .join('\n');
        final confirmed = await showAppConfirmDialog(
          context,
          title: 'Turni nel periodo',
          message:
              'Nel periodo dell\'assenza il dipendente ha '
              '${toRemove.length == 1 ? 'un turno che verrà eliminato' : '${toRemove.length} turni che verranno eliminati'}:\n\n'
              '$elenco\n\nApprovare comunque?',
          confirmLabel: 'Approva ed elimina',
          cancelLabel: 'Annulla',
        );
        if (!confirmed || !mounted) return;
        removeShiftIds = toRemove.map((s) => s.id).toList();
      }
    }

    // Approvando una richiesta con un turno collegato, chiediamo cosa farne (RF6).
    if (approved && request.relatedShiftId != null) {
      final shift = shiftProvider.byId(request.relatedShiftId!);
      // Se il turno non esiste più (già eliminato), approviamo e basta.
      if (shift != null) {
        // Riassegnabile a un collega attivo diverso dall'autore della
        // richiesta e NON assente (ferie/permesso) il giorno del turno.
        final candidates = staffProvider.staff
            .where(
              (m) =>
                  m.isAttivo &&
                  m.uid != request.employeeUid &&
                  !leaveProvider.isOnLeave(m.uid, shift.date),
            )
            .toList();
        final decision = await showApproveShiftSheet(
          context,
          shift: shift,
          candidates: candidates,
        );
        if (decision == null) return; // il responsabile ha annullato
        shiftResolution = decision.resolution;
        reassignToUid = decision.reassignToUid;
      }
    }

    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final ok = await leaveProvider.resolve(
      request.id,
      approved: approved,
      resolvedByUid: auth.currentUser!.uid,
      relatedShiftId: request.relatedShiftId,
      shiftResolution: shiftResolution,
      reassignToUid: reassignToUid,
      // Il nome denormalizzato segue il nuovo assegnatario.
      reassignToName: reassignToUid != null
          ? staffProvider.byUid(reassignToUid)?.name
          : null,
      removeShiftIds: removeShiftIds,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? _successMessage(
                  approved,
                  shiftResolution,
                  removedCount: removeShiftIds.length,
                )
              : (leaveProvider.errorMessage ?? 'Operazione non riuscita.'),
        ),
      ),
    );
  }

  /// Messaggio di conferma coerente con l'azione svolta sui turni.
  String _successMessage(
    bool approved,
    ShiftResolution resolution, {
    int removedCount = 0,
  }) {
    if (!approved) return 'Richiesta rifiutata.';
    if (removedCount > 0) {
      return 'Richiesta approvata · '
          '${removedCount == 1 ? '1 turno eliminato' : '$removedCount turni eliminati'}.';
    }
    return switch (resolution) {
      ShiftResolution.reassign => 'Richiesta approvata e turno riassegnato.',
      ShiftResolution.remove => 'Richiesta approvata e turno eliminato.',
      ShiftResolution.keep => 'Richiesta approvata.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LeaveRequestProvider>();
    final staffProvider = context.watch<StaffProvider>();
    final shiftProvider = context.watch<ShiftProvider>();

    return RequestsListView(
      isLoading: provider.isLoading,
      errorMessage: provider.errorMessage,
      requests: provider.requests,
      emptyIcon: Icons.inbox_rounded,
      emptyTitle: 'Nessuna richiesta',
      emptySubtitle: 'Le richieste inviate dai dipendenti compariranno qui.',
      // Per chi gestisce, le richieste in attesa sono una coda di lavoro.
      pendingSectionTitle: 'Da gestire',
      // Nome "vivo" dall'anagrafica se c'è; altrimenti quello fotografato
      // sulla richiesta (il dipendente potrebbe essere stato rimosso).
      employeeNameFor: (request) =>
          staffProvider.byUid(request.employeeUid)?.name ??
          (request.employeeName.isNotEmpty
              ? request.employeeName
              : 'Dipendente'),
      relatedShiftFor: (request) => request.relatedShiftId == null
          ? null
          : shiftProvider.byId(request.relatedShiftId!),
      actionsFor: (request) => request.status == LeaveStatus.inAttesa
          ? _buildActions(request)
          : null,
    );
  }

  Widget _buildActions(LeaveRequest request) {
    // Disabilitiamo i pulsanti durante un salvataggio in corso.
    final isSaving = context.watch<LeaveRequestProvider>().isSaving;
    final theme = Theme.of(context);
    final statusColors = theme.statusColors;
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: statusColors.danger),
          onPressed: isSaving ? null : () => _resolve(request, approved: false),
          icon: const Icon(Icons.close_rounded),
          label: const Text('Rifiuta'),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: statusColors.success,
            // In dark mode il verde è chiaro: serve testo scuro per leggerlo.
            foregroundColor: isDark ? const Color(0xFF04382B) : Colors.white,
          ),
          onPressed: isSaving ? null : () => _resolve(request, approved: true),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Approva'),
        ),
      ],
    );
  }
}
