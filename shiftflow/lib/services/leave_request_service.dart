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

  /// Riferimento a un turno del locale (serve per aggiornarlo/eliminarlo nella
  /// stessa transazione dell'approvazione, RF6).
  DocumentReference<Map<String, dynamic>> _shiftRef(
    String restaurantId,
    String shiftId,
  ) => _db
      .collection(FirestoreCollections.restaurants)
      .doc(restaurantId)
      .collection(FirestoreCollections.shifts)
      .doc(shiftId);

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
  /// In caso di APPROVAZIONE può anche agire sul turno collegato (RF6):
  /// [shiftResolution] decide se lasciarlo com'è, riassegnarlo a
  /// [reassignToUid] o eliminarlo. L'azione avviene nella STESSA transazione
  /// dell'approvazione, così le due scritture sono atomiche: o riescono
  /// entrambe o nessuna. Se il turno nel frattempo è stato eliminato,
  /// l'approvazione va comunque a buon fine (semplicemente non lo tocca).
  Future<void> resolveRequest(
    String restaurantId,
    String requestId, {
    required bool approved,
    required String resolvedByUid,
    String? relatedShiftId,
    ShiftResolution shiftResolution = ShiftResolution.keep,
    String? reassignToUid,
    String? reassignToName,
    List<String> removeShiftIds = const [],
  }) async {
    final reqRef = _ref(restaurantId).doc(requestId);

    // Tocchiamo il turno solo se: si approva, c'è un turno collegato e la
    // scelta non è "lascia invariato".
    final touchesShift =
        approved &&
        relatedShiftId != null &&
        shiftResolution != ShiftResolution.keep;
    final shiftRef = touchesShift
        ? _shiftRef(restaurantId, relatedShiftId)
        : null;

    await _db.runTransaction((tx) async {
      // In una transazione tutte le LETTURE vanno prima delle scritture.
      final reqSnap = await tx.get(reqRef);
      if (!reqSnap.exists) {
        throw const LeaveRequestException('La richiesta non esiste più.');
      }
      if (reqSnap.data()?['status'] != LeaveStatus.inAttesa) {
        throw const LeaveRequestException(
          'La richiesta è già stata gestita o annullata.',
        );
      }

      DocumentSnapshot<Map<String, dynamic>>? shiftSnap;
      if (shiftRef != null) {
        shiftSnap = await tx.get(shiftRef);
      }

      // --- Scritture. ---
      tx.update(reqRef, {
        'status': approved ? LeaveStatus.approvata : LeaveStatus.rifiutata,
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': resolvedByUid,
      });

      // Il turno lo modifichiamo solo se esiste ancora.
      if (shiftRef != null && shiftSnap != null && shiftSnap.exists) {
        switch (shiftResolution) {
          case ShiftResolution.remove:
            tx.delete(shiftRef);
          case ShiftResolution.reassign:
            if (reassignToUid != null) {
              tx.update(shiftRef, {
                'employeeUid': reassignToUid,
                // Aggiorniamo anche il nome denormalizzato: deve seguire
                // il nuovo assegnatario, non restare quello vecchio.
                // Il `?` salta la voce se il nome è null.
                'employeeName': ?reassignToName,
              });
            }
          case ShiftResolution.keep:
            break; // già escluso sopra; incluso per esaustività
        }
      }

      // Approvando ferie/permesso, i turni del dipendente che cadono nel
      // periodo vengono eliminati QUI, nella stessa transazione: o
      // l'approvazione e le cancellazioni riescono tutte, o nessuna
      // (niente stati a metà se la rete cade).
      if (approved) {
        for (final id in removeShiftIds) {
          tx.delete(_shiftRef(restaurantId, id));
        }
      }
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
