import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/restaurant.dart';

/// Wrapper Firestore per il locale (`restaurants/{rid}`) e la sua anagrafica
/// personale (subcollection `staff`).
class RestaurantService {
  // ignore: unused_field  (usato quando implementeremo i metodi)
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Legge i dati di un locale.
  Future<Restaurant?> getRestaurant(String restaurantId) async {
    // TODO: get del documento restaurants/{restaurantId}.
    throw UnimplementedError();
  }

  /// Crea un nuovo locale e restituisce il suo id.
  Future<String> createRestaurant(Restaurant restaurant) async {
    // TODO: add/set su collection restaurants.
    throw UnimplementedError();
  }

  /// Stream in tempo reale dell'elenco personale del locale.
  Stream<List<AppUser>> watchStaff(String restaurantId) {
    // TODO: snapshots() della subcollection staff -> lista di AppUser.
    throw UnimplementedError();
  }

  /// Aggiunge un membro allo staff del locale.
  Future<void> addStaff(String restaurantId, AppUser member) async {
    // TODO: set su restaurants/{rid}/staff/{uid}.
    throw UnimplementedError();
  }

  /// Rimuove un membro dallo staff del locale.
  Future<void> removeStaff(String restaurantId, String uid) async {
    // TODO: delete su restaurants/{rid}/staff/{uid}.
    throw UnimplementedError();
  }
}
