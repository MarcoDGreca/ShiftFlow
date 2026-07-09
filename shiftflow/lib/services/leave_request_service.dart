import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/leave_request.dart';

/// Wrapper Firestore per le richieste di permesso/cambio turno
/// (`restaurants/{rid}/leaveRequests`).
class LeaveRequestService {
  // ignore: unused_field  (usato quando implementeremo i metodi)
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Richieste inviate da un singolo dipendente (storico personale).
  Stream<List<LeaveRequest>> watchRequestsForEmployee(
    String restaurantId,
    String employeeUid,
  ) {
    // TODO: query where employeeUid == ... -> snapshots -> List<LeaveRequest>.
    throw UnimplementedError();
  }

  /// Tutte le richieste del locale (coda del Responsabile).
  Stream<List<LeaveRequest>> watchAllRequests(String restaurantId) {
    // TODO: snapshots() della collection leaveRequests.
    throw UnimplementedError();
  }

  /// Crea una nuova richiesta (stato iniziale "in_attesa").
  Future<void> createRequest(
    String restaurantId,
    LeaveRequest request,
  ) async {
    // TODO: add su restaurants/{rid}/leaveRequests.
    throw UnimplementedError();
  }

  /// Approva o rifiuta una richiesta (imposta status, resolvedAt, resolvedBy).
  Future<void> resolveRequest(
    String restaurantId,
    String requestId, {
    required bool approved,
    required String resolvedByUid,
  }) async {
    // TODO: update dello status a "approvata"/"rifiutata".
    throw UnimplementedError();
  }
}
