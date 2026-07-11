import 'package:cloud_firestore/cloud_firestore.dart';

/// Rappresenta il documento `restaurants/{restaurantId}`: il locale (tenant).
class Restaurant {
  final String id;
  final String name;
  final String address;
  final String ownerUid;
  final DateTime? createdAt;

  const Restaurant({
    required this.id,
    required this.name,
    required this.address,
    required this.ownerUid,
    this.createdAt,
  });

  factory Restaurant.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Restaurant(
      id: doc.id,
      name: data['name'] as String? ?? '',
      address: data['address'] as String? ?? '',
      ownerUid: data['ownerUid'] as String? ?? '',
      // In Firestore i timestamp arrivano come `Timestamp`: li convertiamo
      // nel tipo `DateTime` di Dart.
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'address': address,
    'ownerUid': ownerUid,
    // `serverTimestamp()` fa impostare l'ora al server, non al telefono.
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
  };
}
