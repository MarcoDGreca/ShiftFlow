import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../models/leave_request.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_request_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/leave_request_card.dart';
import '../../widgets/placeholder_view.dart';

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
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      final rid = user.restaurantId;
      // Sottoscrizioni idempotenti: richieste + staff (nomi) + turni (dettaglio).
      context.read<LeaveRequestProvider>().listenForRestaurant(rid);
      context.read<StaffProvider>().listenForRestaurant(rid);
      context.read<ShiftProvider>().listenForRestaurant(rid);
    }
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
        content: Text(ok
            ? (approved ? 'Richiesta approvata.' : 'Richiesta rifiutata.')
            : (provider.errorMessage ?? 'Operazione non riuscita.')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LeaveRequestProvider>();
    final staffProvider = context.watch<StaffProvider>();
    final shiftProvider = context.watch<ShiftProvider>();

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.errorMessage != null && provider.requests.isEmpty) {
      return PlaceholderView(
        icon: Icons.error_outline,
        title: 'Qualcosa è andato storto',
        subtitle: provider.errorMessage!,
      );
    }
    if (provider.requests.isEmpty) {
      return const PlaceholderView(
        icon: Icons.inbox_outlined,
        title: 'Nessuna richiesta',
        subtitle: 'Le richieste inviate dai dipendenti compariranno qui.',
      );
    }

    final requests = provider.requests;
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: requests.length,
      itemBuilder: (context, i) {
        final request = requests[i];
        final isPending = request.status == LeaveStatus.inAttesa;
        return LeaveRequestCard(
          request: request,
          employeeName:
              staffProvider.byUid(request.employeeUid)?.name ?? 'Dipendente',
          relatedShift: request.relatedShiftId == null
              ? null
              : shiftProvider.byId(request.relatedShiftId!),
          actions: isPending ? _buildActions(request) : null,
        );
      },
    );
  }

  Widget _buildActions(LeaveRequest request) {
    // Disabilitiamo i pulsanti durante un salvataggio in corso.
    final isSaving = context.watch<LeaveRequestProvider>().isSaving;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed:
              isSaving ? null : () => _resolve(request, approved: false),
          icon: const Icon(Icons.close),
          label: const Text('Rifiuta'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: isSaving ? null : () => _resolve(request, approved: true),
          icon: const Icon(Icons.check),
          label: const Text('Approva'),
        ),
      ],
    );
  }
}
