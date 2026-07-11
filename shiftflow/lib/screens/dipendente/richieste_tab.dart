import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../models/leave_request.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_request_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/leave_request_card.dart';
import '../../widgets/placeholder_view.dart';
import 'new_request_screen.dart';

/// Sezione "Le mie richieste" del Dipendente: elenco delle proprie richieste
/// (in attesa e già risolte, quindi anche lo storico) con invio di una nuova.
class RichiesteTab extends StatefulWidget {
  const RichiesteTab({super.key});

  @override
  State<RichiesteTab> createState() => _RichiesteTabState();
}

class _RichiesteTabState extends State<RichiesteTab> {
  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      context
          .read<LeaveRequestProvider>()
          .listenForEmployee(user.restaurantId, user.uid);
      // Serve per il turno collegato (elenco nel form e dettaglio nelle card).
      context
          .read<ShiftProvider>()
          .listenForEmployee(user.restaurantId, user.uid);
    }
  }

  /// Pulsante "Annulla richiesta", disabilitato durante un salvataggio in corso.
  Widget _buildCancelAction(LeaveRequest request) {
    final isSaving = context.watch<LeaveRequestProvider>().isSaving;
    return OutlinedButton.icon(
      onPressed: isSaving ? null : () => _cancel(request),
      icon: const Icon(Icons.undo),
      label: const Text('Annulla richiesta'),
    );
  }

  Future<void> _cancel(LeaveRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annullare la richiesta?'),
        content: const Text(
            'La richiesta verrà ritirata e il responsabile non la vedrà più '
            'tra quelle da gestire.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sì, annulla'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    final auth = context.read<AuthProvider>();
    final provider = context.read<LeaveRequestProvider>();
    final ok =
        await provider.cancel(request.id, employeeUid: auth.currentUser!.uid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Richiesta annullata.'
            : (provider.errorMessage ?? 'Operazione non riuscita.')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LeaveRequestProvider>();
    final shiftProvider = context.watch<ShiftProvider>();

    final Widget body;
    if (provider.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (provider.errorMessage != null && provider.requests.isEmpty) {
      body = PlaceholderView(
        icon: Icons.error_outline,
        title: 'Qualcosa è andato storto',
        subtitle: provider.errorMessage!,
      );
    } else if (provider.requests.isEmpty) {
      body = const PlaceholderView(
        icon: Icons.mail_outline,
        title: 'Nessuna richiesta',
        subtitle: 'Invia la tua prima richiesta con il pulsante + qui sotto.',
      );
    } else {
      final requests = provider.requests;
      body = ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
        itemCount: requests.length,
        itemBuilder: (context, i) {
          final request = requests[i];
          final isPending = request.status == LeaveStatus.inAttesa;
          return LeaveRequestCard(
            request: request,
            relatedShift: request.relatedShiftId == null
                ? null
                : shiftProvider.byId(request.relatedShiftId!),
            actions: isPending ? _buildCancelAction(request) : null,
          );
        },
      );
    }

    return Scaffold(
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NewRequestScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuova richiesta'),
      ),
    );
  }
}
