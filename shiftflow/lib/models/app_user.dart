import 'package:cloud_firestore/cloud_firestore.dart';

/// Rappresenta il documento `users/{uid}`, letto subito dopo il login per
/// sapere a quale locale appartiene l'utente e con quale ruolo.
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

  const AppUser({
    required this.uid,
    required this.restaurantId,
    required this.role,
    required this.name,
    required this.email,
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
    );
  }

  /// Mappa da salvare su Firestore. Nota: `uid` non è incluso perché è
  /// l'id del documento, non un campo al suo interno.
  Map<String, dynamic> toFirestore() => {
        'restaurantId': restaurantId,
        'role': role,
        'name': name,
        'email': email,
      };

  bool get isResponsabile => role == 'responsabile';
  bool get isDipendente => role == 'dipendente';
}
