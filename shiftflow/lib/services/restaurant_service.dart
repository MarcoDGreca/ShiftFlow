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

  /// Legge i dati di un locale.
  Future<Restaurant?> getRestaurant(String restaurantId) async {
    // TODO: get del documento restaurants/{restaurantId}.
    throw UnimplementedError();
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
    return _staffRef(restaurantId)
        .snapshots()
        .map((snap) => snap.docs.map(AppUser.fromFirestore).toList());
  }

  /// Aggiunge un membro allo staff del locale.
  Future<void> addStaff(String restaurantId, AppUser member) async {
    // TODO: set su restaurants/{rid}/staff/{uid} (RF8).
    throw UnimplementedError();
  }

  /// Rimuove un membro dallo staff del locale.
  Future<void> removeStaff(String restaurantId, String uid) async {
    // TODO: delete su restaurants/{rid}/staff/{uid} (RF8).
    throw UnimplementedError();
  }
}
