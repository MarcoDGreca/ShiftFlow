import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_status_colors.dart';
import '../../models/leave_request.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_request_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/requests_list_view.dart';

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
    final auth = context.read<AuthProvider>();
    final provider = context.read<LeaveRequestProvider>();
    final ok = await provider.resolve(
      request.id,
      approved: approved,
      resolvedByUid: auth.currentUser!.uid,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (approved ? 'Richiesta approvata.' : 'Richiesta rifiutata.')
              : (provider.errorMessage ?? 'Operazione non riuscita.'),
        ),
      ),
    );
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
      employeeNameFor: (request) =>
          staffProvider.byUid(request.employeeUid)?.name ?? 'Dipendente',
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
