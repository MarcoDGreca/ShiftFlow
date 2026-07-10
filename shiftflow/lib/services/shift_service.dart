import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/shift.dart';

/// Wrapper Firestore per i turni (`restaurants/{rid}/shifts`).
class ShiftService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Riferimento alla subcollection dei turni di un locale.
  CollectionReference<Map<String, dynamic>> _shiftsRef(String restaurantId) =>
      _db
          .collection(FirestoreCollections.restaurants)
          .doc(restaurantId)
          .collection(FirestoreCollections.shifts);

  /// Ordina per data e, a parità di giorno, per orario di inizio.
  ///
  /// L'ordinamento è fatto in memoria e non nella query: `where` + `orderBy`
  /// su campi diversi richiederebbe un indice composito su Firestore; con i
  /// volumi di un singolo locale non ne vale la pena.
  List<Shift> _sorted(List<Shift> shifts) {
    shifts.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      return a.startTime.compareTo(b.startTime);
    });
    return shifts;
  }

  /// Turni di un singolo dipendente (vista Dipendente).
  Stream<List<Shift>> watchShiftsForEmployee(
    String restaurantId,
    String employeeUid,
  ) {
    return _shiftsRef(restaurantId)
        .where('employeeUid', isEqualTo: employeeUid)
        .snapshots()
        .map((snap) => _sorted(snap.docs.map(Shift.fromFirestore).toList()));
  }

  /// Tutti i turni del locale (calendario completo, vista Responsabile).
  Stream<List<Shift>> watchAllShifts(String restaurantId) {
    return _shiftsRef(restaurantId)
        .snapshots()
        .map((snap) => _sorted(snap.docs.map(Shift.fromFirestore).toList()));
  }

  Future<void> createShift(String restaurantId, Shift shift) async {
    await _shiftsRef(restaurantId).add(shift.toFirestore());
  }

  Future<void> updateShift(String restaurantId, Shift shift) async {
    await _shiftsRef(restaurantId).doc(shift.id).update(shift.toFirestore());
  }

  Future<void> deleteShift(String restaurantId, String shiftId) async {
    await _shiftsRef(restaurantId).doc(shiftId).delete();
  }
}
