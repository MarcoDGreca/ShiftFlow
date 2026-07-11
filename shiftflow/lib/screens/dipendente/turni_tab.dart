import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/shift.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/glass_container.dart';
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
    // A fine frame: il provider fa notifyListeners() subito, e farlo durante
    // la costruzione del widget non è permesso.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) {
        // Sottoscrizione ai SOLI turni di questo dipendente.
        context.read<ShiftProvider>().listenForEmployee(
          user.restaurantId,
          user.uid,
        );
      }
    });
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
    // Le barre della home sono trasparenti: il contenuto fisso (banner e
    // filtro) deve partire sotto la AppBar, e la lista finire oltre la
    // NavigationBar.
    final insets = MediaQuery.paddingOf(context);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Partiamo dalla lista già ordinata (data, poi orario) dal provider.
    final prossimi = shiftProvider.shifts
        .where((s) => !_isPast(s, today))
        .toList();
    // I passati li mostriamo dal più recente al più vecchio.
    final passati = shiftProvider.shifts
        .where((s) => _isPast(s, today))
        .toList()
        .reversed
        .toList();

    final visibili = _filtro == _Filtro.prossimi ? prossimi : passati;

    return Column(
      children: [
        SizedBox(height: insets.top),
        SyncStatusBanner(
          isFromCache: shiftProvider.isFromCache,
          hasPendingWrites: shiftProvider.hasPendingWrites,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
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
                icon: Icon(Icons.history_rounded),
              ),
            ],
            selected: {_filtro},
            onSelectionChanged: (selection) =>
                setState(() => _filtro = selection.first),
          ),
        ),
        Expanded(
          child: AsyncStateView(
            isLoading: shiftProvider.isLoading,
            errorMessage: shiftProvider.errorMessage,
            isEmpty: visibili.isEmpty,
            emptyIcon: Icons.event_busy_rounded,
            emptyTitle: _filtro == _Filtro.prossimi
                ? 'Nessun turno in programma'
                : 'Nessun turno passato',
            emptySubtitle: _filtro == _Filtro.prossimi
                ? 'Quando il responsabile ti assegnerà un turno, comparirà qui.'
                : 'Qui troverai lo storico dei tuoi turni.',
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.sm,
                0,
                AppSpacing.sm,
                AppSpacing.md + insets.bottom,
              ),
              itemCount: visibili.length,
              itemBuilder: (context, i) => _ShiftCard(shift: visibili[i]),
            ),
          ),
        ),
      ],
    );
  }
}

/// Card di un singolo turno nella vista Dipendente (sola lettura):
/// blocco orario in evidenza a sinistra, data e note a destra.
class _ShiftCard extends StatelessWidget {
  final Shift shift;

  const _ShiftCard({required this.shift});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  shift.startTime,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  shift.endTime,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormatter.full(shift.date),
                  style: theme.textTheme.titleMedium,
                ),
                if (shift.notes != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    shift.notes!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
