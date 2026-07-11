import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/leave_request.dart';

/// Errore "atteso" di dominio: l'operazione richiesta non è più valida
/// (es. una richiesta che qualcun altro ha già gestito o annullato).
///
/// Porta con sé un [message] già in italiano e pronto da mostrare all'utente,
/// così il Provider può distinguerlo da un guasto generico.
class LeaveRequestException implements Exception {
  final String message;
  const LeaveRequestException(this.message);

  @override
  String toString() => 'LeaveRequestException: $message';
}

/// Wrapper Firestore per le richieste di permesso/cambio turno
/// (`restaurants/{rid}/leaveRequests`).
class LeaveRequestService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _ref(String restaurantId) => _db
      .collection(FirestoreCollections.restaurants)
      .doc(restaurantId)
      .collection(FirestoreCollections.leaveRequests);

  /// Ordina: prima le richieste "in attesa" (sono quelle su cui agire), poi
  /// per data di invio decrescente (più recenti in alto). Fatto in memoria per
  /// non richiedere indici compositi.
  List<LeaveRequest> _sorted(List<LeaveRequest> list) {
    list.sort((a, b) {
      final aPending = a.status == LeaveStatus.inAttesa;
      final bPending = b.status == LeaveStatus.inAttesa;
      if (aPending != bPending) return aPending ? -1 : 1;
      final aDate = a.createdAt ?? DateTime(1970);
      final bDate = b.createdAt ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });
    return list;
  }

  /// Richieste inviate da un singolo dipendente (storico personale, RF9).
  Stream<List<LeaveRequest>> watchRequestsForEmployee(
    String restaurantId,
    String employeeUid,
  ) {
    return _ref(restaurantId)
        .where('employeeUid', isEqualTo: employeeUid)
        .snapshots()
        .map((s) => _sorted(s.docs.map(LeaveRequest.fromFirestore).toList()));
  }

  /// Tutte le richieste del locale (coda del Responsabile).
  Stream<List<LeaveRequest>> watchAllRequests(String restaurantId) {
    return _ref(restaurantId).snapshots().map(
      (s) => _sorted(s.docs.map(LeaveRequest.fromFirestore).toList()),
    );
  }

  /// Crea una nuova richiesta (stato iniziale "in_attesa").
  Future<void> createRequest(String restaurantId, LeaveRequest request) async {
    await _ref(restaurantId).add(request.toFirestore());
  }

  /// Approva o rifiuta una richiesta, in **transazione** (vedi §7.2 del brief).
  ///
  /// Il caso critico: il dipendente annulla la richiesta nello stesso istante
  /// in cui il responsabile la sta decidendo. La transazione rilegge lo stato
  /// corrente e scrive l'esito solo se la richiesta è ancora "in attesa";
  /// altrimenti si ferma e segnala l'esito reale. Firestore rielabora la
  /// transazione se il documento cambia nel frattempo, quindi il controllo è
  /// sempre fatto su dati aggiornati: "vince chi scrive per primo".
  Future<void> resolveRequest(
    String restaurantId,
    String requestId, {
    required bool approved,
    required String resolvedByUid,
  }) async {
    final ref = _ref(restaurantId).doc(requestId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw const LeaveRequestException('La richiesta non esiste più.');
      }
      if (snap.data()?['status'] != LeaveStatus.inAttesa) {
        throw const LeaveRequestException(
          'La richiesta è già stata gestita o annullata.',
        );
      }
      tx.update(ref, {
        'status': approved ? LeaveStatus.approvata : LeaveStatus.rifiutata,
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': resolvedByUid,
      });
    });
  }

  /// Il dipendente annulla la **propria** richiesta, in transazione: speculare
  /// a [resolveRequest] (§7.2). Consentito solo finché è ancora "in attesa";
  /// se il responsabile l'ha già decisa nel frattempo, l'annullamento fallisce
  /// e la UI mostra l'esito reale.
  Future<void> cancelRequest(
    String restaurantId,
    String requestId, {
    required String employeeUid,
  }) async {
    final ref = _ref(restaurantId).doc(requestId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw const LeaveRequestException('La richiesta non esiste più.');
      }
      final data = snap.data()!;
      if (data['employeeUid'] != employeeUid) {
        throw const LeaveRequestException(
          'Puoi annullare solo le tue richieste.',
        );
      }
      if (data['status'] != LeaveStatus.inAttesa) {
        throw const LeaveRequestException(
          'La richiesta è già stata gestita e non può essere annullata.',
        );
      }
      tx.update(ref, {'status': LeaveStatus.annullata});
    });
  }
}
