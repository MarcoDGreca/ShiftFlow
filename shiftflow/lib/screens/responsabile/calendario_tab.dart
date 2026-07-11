import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_formatter.dart';
import '../../models/shift.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/placeholder_view.dart';
import '../../widgets/sync_status_banner.dart';
import 'shift_form_screen.dart';

/// Sezione "Calendario" del Responsabile: elenco in tempo reale di tutti i
/// turni del locale, con creazione (FAB), modifica (tap) ed eliminazione
/// (icona cestino con conferma).
class CalendarioTab extends StatefulWidget {
  const CalendarioTab({super.key});

  @override
  State<CalendarioTab> createState() => _CalendarioTabState();
}

class _CalendarioTabState extends State<CalendarioTab> {
  @override
  void initState() {
    super.initState();
    // Avvia le sottoscrizioni (idempotenti: se già attive non fanno nulla).
    // Lo staff serve per mostrare il nome accanto a ogni turno e per il form.
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      context.read<ShiftProvider>().listenForRestaurant(user.restaurantId);
      context.read<StaffProvider>().listenForRestaurant(user.restaurantId);
    }
  }

  Future<void> _confirmDelete(Shift shift) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminare il turno?'),
        content: const Text('Questa operazione non si può annullare.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await context.read<ShiftProvider>().deleteShift(shift.id);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<ShiftProvider>().errorMessage ??
              'Eliminazione non riuscita.'),
        ),
      );
    }
  }

  void _openForm({Shift? existing}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ShiftFormScreen(existing: existing)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shiftProvider = context.watch<ShiftProvider>();
    final staffProvider = context.watch<StaffProvider>();

    final Widget body;
    if (shiftProvider.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (shiftProvider.errorMessage != null) {
      body = PlaceholderView(
        icon: Icons.error_outline,
        title: 'Qualcosa è andato storto',
        subtitle: shiftProvider.errorMessage!,
      );
    } else if (shiftProvider.shifts.isEmpty) {
      body = const PlaceholderView(
        icon: Icons.calendar_month,
        title: 'Nessun turno',
        subtitle: 'Crea il primo turno con il pulsante + qui sotto.',
      );
    } else {
      final shifts = shiftProvider.shifts;
      body = ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 88), // spazio per il FAB
        itemCount: shifts.length,
        itemBuilder: (context, i) {
          final shift = shifts[i];
          final employeeName =
              staffProvider.byUid(shift.employeeUid)?.name ?? 'Dipendente';
          return Card(
            child: ListTile(
              leading: const Icon(Icons.event),
              title: Text(employeeName),
              subtitle: Text(
                '${DateFormatter.full(shift.date)}'
                ' · ${shift.startTime}–${shift.endTime}'
                '${shift.notes != null ? '\n${shift.notes}' : ''}',
              ),
              isThreeLine: shift.notes != null,
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Elimina turno',
                onPressed: () => _confirmDelete(shift),
              ),
              onTap: () => _openForm(existing: shift),
            ),
          );
        },
      );
    }

    // Scaffold annidato (senza AppBar, che è della home): serve solo per
    // ancorare il FAB a QUESTA sezione e non alle altre schede.
    return Scaffold(
      body: Column(
        children: [
          SyncStatusBanner(
            isFromCache: shiftProvider.isFromCache,
            hasPendingWrites: shiftProvider.hasPendingWrites,
          ),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('Nuovo turno'),
      ),
    );
  }
}
