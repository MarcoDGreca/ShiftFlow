import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/dialogs.dart';
import '../../models/leave_request.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_request_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/requests_list_view.dart';
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
    // A fine frame: il provider fa notifyListeners() subito, e farlo durante
    // la costruzione del widget non è permesso.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) {
        context.read<LeaveRequestProvider>().listenForEmployee(
          user.restaurantId,
          user.uid,
        );
        // Serve per il turno collegato (elenco nel form e dettaglio nelle card).
        context.read<ShiftProvider>().listenForEmployee(
          user.restaurantId,
          user.uid,
        );
      }
    });
  }

  /// Pulsante "Annulla richiesta", disabilitato durante un salvataggio in corso.
  Widget _buildCancelAction(LeaveRequest request) {
    final isSaving = context.watch<LeaveRequestProvider>().isSaving;
    return OutlinedButton.icon(
      onPressed: isSaving ? null : () => _cancel(request),
      icon: const Icon(Icons.undo_rounded),
      label: const Text('Annulla richiesta'),
    );
  }

  Future<void> _cancel(LeaveRequest request) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Annullare la richiesta?',
      message:
          'La richiesta verrà ritirata e il responsabile non la vedrà '
          'più tra quelle da gestire.',
      confirmLabel: 'Sì, annulla',
      cancelLabel: 'No',
    );
    if (!mounted || !confirmed) return;

    final auth = context.read<AuthProvider>();
    final provider = context.read<LeaveRequestProvider>();
    final ok = await provider.cancel(
      request.id,
      employeeUid: auth.currentUser!.uid,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Richiesta annullata.'
              : (provider.errorMessage ?? 'Operazione non riuscita.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LeaveRequestProvider>();
    final shiftProvider = context.watch<ShiftProvider>();

    // Scaffold annidato (senza AppBar, che è della home): serve solo per
    // ancorare il FAB a QUESTA sezione. Trasparente per lasciar vedere
    // lo sfondo ambientale della home.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RequestsListView(
        isLoading: provider.isLoading,
        errorMessage: provider.errorMessage,
        requests: provider.requests,
        emptyIcon: Icons.mail_outline_rounded,
        emptyTitle: 'Nessuna richiesta',
        emptySubtitle:
            'Invia la tua prima richiesta con il pulsante + qui sotto.',
        relatedShiftFor: (request) => request.relatedShiftId == null
            ? null
            : shiftProvider.byId(request.relatedShiftId!),
        actionsFor: (request) => request.status == LeaveStatus.inAttesa
            ? _buildCancelAction(request)
            : null,
        bottomClearance: AppSizes.fabClearance,
      ),
      // Il Padding alza il FAB sopra la NavigationBar trasparente della home
      // (lo Scaffold interno non sa quanto è alta: glielo diciamo noi).
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const NewRequestScreen()));
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nuova richiesta'),
        ),
      ),
    );
  }
}
