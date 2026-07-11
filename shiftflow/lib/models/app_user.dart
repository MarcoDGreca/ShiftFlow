import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';

/// Rappresenta il documento `users/{uid}`, letto subito dopo il login per
/// sapere a quale locale appartiene l'utente e con quale ruolo. Lo stesso
/// modello viene riusato per leggere i documenti `staff/{uid}`, che portano
/// anche lo `status` (attivo / disattivato).
///
/// I modelli conoscono `cloud_firestore` solo per convertire da/verso i
/// documenti (`fromFirestore`/`toFirestore`). La logica di lettura/scrittura
/// vera resta nei Service: i widget non toccano mai direttamente Firestore.
class AppUser {
  final String uid;
  final String restaurantId;
  final String role; // vedi UserRoles
  final String name;
  final String email;
  final String status; // vedi StaffStatus

  const AppUser({
    required this.uid,
    required this.restaurantId,
    required this.role,
    required this.name,
    required this.email,
    this.status = StaffStatus.attivo,
  });

  /// Costruisce un [AppUser] a partire dal documento Firestore.
  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppUser(
      uid: doc.id,
      restaurantId: data['restaurantId'] as String? ?? '',
      role: data['role'] as String? ?? '',
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      // I vecchi documenti senza `status` sono considerati attivi.
      status: data['status'] as String? ?? StaffStatus.attivo,
    );
  }

  /// Mappa da salvare su Firestore. Nota: `uid` non è incluso perché è
  /// l'id del documento, non un campo al suo interno.
  Map<String, dynamic> toFirestore() => {
    'restaurantId': restaurantId,
    'role': role,
    'name': name,
    'email': email,
    'status': status,
  };

  bool get isResponsabile => role == 'responsabile';
  bool get isDipendente => role == 'dipendente';
  bool get isAttivo => status == StaffStatus.attivo;
  bool get isDisattivato => status == StaffStatus.disattivato;
}
