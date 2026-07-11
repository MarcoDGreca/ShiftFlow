import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import '../models/leave_request.dart';
import '../models/shift.dart';
import 'async_state_view.dart';
import 'leave_request_card.dart';

/// Lista di richieste condivisa tra Dipendente e Responsabile: stati di
/// caricamento/errore/vuoto e card delle richieste. Le differenze tra i due
/// ruoli (nome del mittente, pulsanti azione) arrivano dai callback.
class RequestsListView extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final List<LeaveRequest> requests;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;

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
    this.employeeNameFor,
    this.actionsFor,
    this.bottomClearance = AppSpacing.sm,
  });

  @override
  Widget build(BuildContext context) {
    // Le barre della home sono trasparenti e il contenuto ci passa sotto:
    // il primo e l'ultimo elemento però devono partire oltre i loro bordi.
    final insets = MediaQuery.paddingOf(context);

    return AsyncStateView(
      isLoading: isLoading,
      errorMessage: errorMessage,
      isEmpty: requests.isEmpty,
      emptyIcon: emptyIcon,
      emptyTitle: emptyTitle,
      emptySubtitle: emptySubtitle,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.sm,
          insets.top + AppSpacing.sm,
          AppSpacing.sm,
          insets.bottom + bottomClearance,
        ),
        itemCount: requests.length,
        itemBuilder: (context, i) {
          final request = requests[i];
          return LeaveRequestCard(
            request: request,
            employeeName: employeeNameFor?.call(request),
            relatedShift: relatedShiftFor(request),
            actions: actionsFor?.call(request),
          );
        },
      ),
    );
  }
}
