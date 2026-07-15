import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_spacing.dart';
import '../models/leave_request.dart';
import '../models/shift.dart';
import 'async_state_view.dart';
import 'leave_request_card.dart';
import 'section_header.dart';

/// I filtri di stato della lista richieste. "Tutte" mostra anche annullate
/// e decadute; gli altri isolano un singolo stato.
enum _RequestFilter { tutte, inAttesa, approvate, rifiutate }

extension on _RequestFilter {
  String get label => switch (this) {
    _RequestFilter.tutte => 'Tutte',
    _RequestFilter.inAttesa => 'In attesa',
    _RequestFilter.approvate => 'Approvate',
    _RequestFilter.rifiutate => 'Rifiutate',
  };

  bool matches(LeaveRequest request) => switch (this) {
    _RequestFilter.tutte => true,
    _RequestFilter.inAttesa => request.status == LeaveStatus.inAttesa,
    _RequestFilter.approvate => request.status == LeaveStatus.approvata,
    _RequestFilter.rifiutate => request.status == LeaveStatus.rifiutata,
  };
}

/// Lista di richieste condivisa tra Dipendente e Responsabile: chip-filtro
/// per stato, richieste "in attesa" raggruppate in cima (sono quelle su cui
/// si agisce), poi lo storico. Le differenze tra i due ruoli (nome del
/// mittente, pulsanti azione, titolo della sezione) arrivano dai parametri.
class RequestsListView extends StatefulWidget {
  final bool isLoading;
  final String? errorMessage;
  final List<LeaveRequest> requests;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;

  /// Titolo della sezione delle richieste in attesa (es. "Da gestire" per il
  /// Responsabile, "In attesa" per il Dipendente).
  final String pendingSectionTitle;

  /// Nome da mostrare sulla card (solo il Responsabile lo usa).
  final String Function(LeaveRequest request)? employeeNameFor;

  /// Turno collegato alla richiesta, se esiste.
  final Shift? Function(LeaveRequest request) relatedShiftFor;

  /// Pulsanti azione per una richiesta (annulla / approva-rifiuta).
  final Widget? Function(LeaveRequest request)? actionsFor;

  /// Spazio extra in fondo alla lista (es. per non finire sotto il FAB).
  final double bottomClearance;

  const RequestsListView({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.requests,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.relatedShiftFor,
    this.pendingSectionTitle = 'In attesa',
    this.employeeNameFor,
    this.actionsFor,
    this.bottomClearance = AppSpacing.sm,
  });

  @override
  State<RequestsListView> createState() => _RequestsListViewState();
}

class _RequestsListViewState extends State<RequestsListView> {
  _RequestFilter _filter = _RequestFilter.tutte;

  @override
  Widget build(BuildContext context) {
    // Le barre della home sono trasparenti e il contenuto ci passa sotto:
    // chip e lista però devono partire oltre i loro bordi.
    final insets = MediaQuery.paddingOf(context);

    final filtered = widget.requests.where(_filter.matches).toList();
    final pendingCount = widget.requests
        .where((r) => r.status == LeaveStatus.inAttesa)
        .length;

    // Con "Tutte" le richieste in attesa salgono in cima con una sezione
    // dedicata: sono le uniche che chiedono un'azione, il resto è storico.
    final pending = _filter == _RequestFilter.tutte
        ? filtered.where((r) => r.status == LeaveStatus.inAttesa).toList()
        : const <LeaveRequest>[];
    final others = _filter == _RequestFilter.tutte
        ? filtered.where((r) => r.status != LeaveStatus.inAttesa).toList()
        : filtered;
    final showSections = pending.isNotEmpty && others.isNotEmpty;

    // Stato vuoto: distinguere "nessuna richiesta" da "il filtro non trova
    // nulla" evita di suggerire azioni sbagliate (feedback onesto).
    final noRequestsAtAll = widget.requests.isEmpty;

    return Column(
      children: [
        SizedBox(height: insets.top + AppSpacing.sm),
        // Chip-filtro scorrevoli: triage veloce senza cambiare schermata.
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: [
              for (final f in _RequestFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(
                      // Il conteggio solo su "In attesa": è il numero che
                      // serve per capire se c'è lavoro da fare.
                      f == _RequestFilter.inAttesa && pendingCount > 0
                          ? '${f.label} ($pendingCount)'
                          : f.label,
                    ),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncStateView(
            isLoading: widget.isLoading,
            errorMessage: widget.errorMessage,
            isEmpty: filtered.isEmpty,
            emptyIcon: noRequestsAtAll
                ? widget.emptyIcon
                : Icons.filter_alt_off_rounded,
            emptyTitle: noRequestsAtAll
                ? widget.emptyTitle
                : 'Niente con questo filtro',
            emptySubtitle: noRequestsAtAll
                ? widget.emptySubtitle
                : 'Nessuna richiesta ha lo stato "${_filter.label}".',
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.sm,
                0,
                AppSpacing.sm,
                insets.bottom + widget.bottomClearance,
              ),
              children: [
                if (showSections)
                  SectionHeader(
                    title: widget.pendingSectionTitle,
                    trailing: '${pending.length}',
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.sm,
                      AppSpacing.sm,
                      AppSpacing.xs,
                    ),
                  ),
                for (final request in pending) _buildCard(request),
                if (showSections)
                  const SectionHeader(
                    title: 'Storico',
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.xs,
                    ),
                  ),
                for (final request in others) _buildCard(request),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(LeaveRequest request) {
    return LeaveRequestCard(
      request: request,
      employeeName: widget.employeeNameFor?.call(request),
      relatedShift: widget.relatedShiftFor(request),
      actions: widget.actionsFor?.call(request),
    );
  }
}
