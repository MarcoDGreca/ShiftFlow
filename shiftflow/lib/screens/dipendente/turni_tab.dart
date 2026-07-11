import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_formatter.dart';
import '../../models/shift.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/placeholder_view.dart';
import '../../widgets/sync_status_banner.dart';

/// Sezione "I miei turni" del Dipendente: elenco in tempo reale dei propri
/// turni, con un filtro Prossimi/Passati (quest'ultimo copre lo storico, RF9).
class TurniTab extends StatefulWidget {
  const TurniTab({super.key});

  @override
  State<TurniTab> createState() => _TurniTabState();
}

/// Le due viste possibili dell'elenco.
enum _Filtro { prossimi, passati }

class _TurniTabState extends State<TurniTab> {
  _Filtro _filtro = _Filtro.prossimi;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      // Sottoscrizione ai SOLI turni di questo dipendente.
      context
          .read<ShiftProvider>()
          .listenForEmployee(user.restaurantId, user.uid);
    }
  }

  /// Un turno è "passato" se il suo giorno è precedente a oggi (l'orario non
  /// conta: un turno di stasera resta tra i "prossimi" per tutta la giornata).
  bool _isPast(Shift shift, DateTime today) {
    final day = DateTime(shift.date.year, shift.date.month, shift.date.day);
    return day.isBefore(today);
  }

  @override
  Widget build(BuildContext context) {
    final shiftProvider = context.watch<ShiftProvider>();

    if (shiftProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (shiftProvider.errorMessage != null) {
      return PlaceholderView(
        icon: Icons.error_outline,
        title: 'Qualcosa è andato storto',
        subtitle: shiftProvider.errorMessage!,
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Partiamo dalla lista già ordinata (data, poi orario) dal provider.
    final prossimi =
        shiftProvider.shifts.where((s) => !_isPast(s, today)).toList();
    // I passati li mostriamo dal più recente al più vecchio.
    final passati = shiftProvider.shifts
        .where((s) => _isPast(s, today))
        .toList()
        .reversed
        .toList();

    final visibili = _filtro == _Filtro.prossimi ? prossimi : passati;

    return Column(
      children: [
        SyncStatusBanner(
          isFromCache: shiftProvider.isFromCache,
          hasPendingWrites: shiftProvider.hasPendingWrites,
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<_Filtro>(
            segments: const [
              ButtonSegment(
                value: _Filtro.prossimi,
                label: Text('Prossimi'),
                icon: Icon(Icons.upcoming_outlined),
              ),
              ButtonSegment(
                value: _Filtro.passati,
                label: Text('Passati'),
                icon: Icon(Icons.history),
              ),
            ],
            selected: {_filtro},
            onSelectionChanged: (selection) =>
                setState(() => _filtro = selection.first),
          ),
        ),
        Expanded(
          child: visibili.isEmpty
              ? PlaceholderView(
                  icon: Icons.event_busy,
                  title: _filtro == _Filtro.prossimi
                      ? 'Nessun turno in programma'
                      : 'Nessun turno passato',
                  subtitle: _filtro == _Filtro.prossimi
                      ? 'Quando il responsabile ti assegnerà un turno, comparirà qui.'
                      : 'Qui troverai lo storico dei tuoi turni.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  itemCount: visibili.length,
                  itemBuilder: (context, i) => _ShiftCard(shift: visibili[i]),
                ),
        ),
      ],
    );
  }
}

/// Card di un singolo turno nella vista Dipendente (sola lettura).
class _ShiftCard extends StatelessWidget {
  final Shift shift;

  const _ShiftCard({required this.shift});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.event),
        title: Text(DateFormatter.full(shift.date)),
        subtitle: Text(
          'Orario: ${shift.startTime}–${shift.endTime}'
          '${shift.notes != null ? '\n${shift.notes}' : ''}',
        ),
        isThreeLine: shift.notes != null,
      ),
    );
  }
}
