import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/app_user.dart';
import '../models/restaurant.dart';

/// Wrapper Firestore per il locale (`restaurants/{rid}`) e la sua anagrafica
/// personale (subcollection `staff`).
class RestaurantService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Riferimento alla subcollection staff di un locale.
  CollectionReference<Map<String, dynamic>> _staffRef(String restaurantId) =>
      _db
          .collection(FirestoreCollections.restaurants)
          .doc(restaurantId)
          .collection(FirestoreCollections.staff);

  /// Riferimento alla subcollection delle richieste di un locale.
  CollectionReference<Map<String, dynamic>> _leaveRef(String restaurantId) =>
      _db
          .collection(FirestoreCollections.restaurants)
          .doc(restaurantId)
          .collection(FirestoreCollections.leaveRequests);

  /// Legge i dati di un locale.
  Future<Restaurant?> getRestaurant(String restaurantId) async {
    final doc = await _db
        .collection(FirestoreCollections.restaurants)
        .doc(restaurantId)
        .get();
    if (!doc.exists) return null;
    return Restaurant.fromFirestore(doc);
  }

  /// Crea un nuovo locale e restituisce il suo id.
  /// Nota: la creazione contestuale alla registrazione avviene già in
  /// AuthService.registerResponsabile; questo servirà per usi futuri.
  Future<String> createRestaurant(Restaurant restaurant) async {
    // TODO: add/set su collection restaurants.
    throw UnimplementedError();
  }

  /// Stream in tempo reale dell'elenco personale del locale.
  Stream<List<AppUser>> watchStaff(String restaurantId) {
    return _staffRef(
      restaurantId,
    ).snapshots().map((snap) => snap.docs.map(AppUser.fromFirestore).toList());
  }

  // Nota: l'AGGIUNTA di un dipendente non è qui ma in
  // AuthService.createDipendente, perché comporta la creazione di un account
  // Firebase Auth (con la tecnica dell'istanza secondaria).

  /// Attiva o disattiva un membro dell'anagrafica (RF7/UC5).
  ///
  /// La disattivazione è "soft": il documento resta (turni e storico intatti),
  /// ma il membro viene escluso dall'assegnazione di nuovi turni. È preferibile
  /// alla rimozione, che è definitiva.
  ///
  /// UC5-E2: al momento della disattivazione, le richieste ancora "in attesa"
  /// del membro vengono chiuse come "decadute" (non hanno più effetto). Lo
  /// stato del membro e la chiusura delle richieste avvengono in un unico
  /// batch atomico: o riescono entrambi o nessuno.
  Future<void> setStaffActive(
    String restaurantId,
    String uid, {
    required bool active,
  }) async {
    final staffRef = _staffRef(restaurantId).doc(uid);

    // Riattivazione: nessuna richiesta da toccare.
    if (active) {
      await staffRef.update({'status': StaffStatus.attivo});
      return;
    }

    // Disattivazione: filtriamo le richieste in attesa in memoria (una sola
    // condizione di uguaglianza nella query = nessun indice composito).
    final requests = await _leaveRef(
      restaurantId,
    ).where('employeeUid', isEqualTo: uid).get();

    final batch = _db.batch();
    batch.update(staffRef, {'status': StaffStatus.disattivato});
    for (final doc in requests.docs) {
      if (doc.data()['status'] == LeaveStatus.inAttesa) {
        batch.update(doc.reference, {
          'status': LeaveStatus.decaduta,
          'resolvedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }

  /// Riferimento alla subcollection dei turni di un locale.
  CollectionReference<Map<String, dynamic>> _shiftsRef(String restaurantId) =>
      _db
          .collection(FirestoreCollections.restaurants)
          .doc(restaurantId)
          .collection(FirestoreCollections.shifts);

  /// Rimuove un membro dall'anagrafica del locale (RF7/UC5, flusso alternativo).
  ///
  /// Prima di cancellare `staff/{uid}` scrive il [name] sui turni e sulle
  /// richieste del membro (campo `employeeName`): l'anagrafica sparisce ma lo
  /// storico resta leggibile ("chi ha lavorato questo turno?"). Sistema anche
  /// i documenti creati prima dell'introduzione del campo. Tutto in un unico
  /// batch atomico.
  ///
  /// Limite noto (accettato per ora): l'account Auth e il documento
  /// `users/{uid}` del dipendente non si possono toccare dal client di un
  /// altro utente; una rimozione completa richiederebbe un backend
  /// (Cloud Functions + Admin SDK).
  Future<void> removeStaff(
    String restaurantId,
    String uid, {
    required String name,
  }) async {
    final batch = _db.batch();

    if (name.isNotEmpty) {
      final shifts = await _shiftsRef(
        restaurantId,
      ).where('employeeUid', isEqualTo: uid).get();
      for (final doc in shifts.docs) {
        batch.update(doc.reference, {'employeeName': name});
      }
      final requests = await _leaveRef(
        restaurantId,
      ).where('employeeUid', isEqualTo: uid).get();
      for (final doc in requests.docs) {
        batch.update(doc.reference, {'employeeName': name});
      }
    }

    batch.delete(_staffRef(restaurantId).doc(uid));
    await batch.commit();
  }
}
