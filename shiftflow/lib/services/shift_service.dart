import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/shift.dart';

/// Wrapper Firestore per i turni (`restaurants/{rid}/shifts`).
class ShiftService {
  // ignore: unused_field  (usato quando implementeremo i metodi)
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Turni di un singolo dipendente (vista Dipendente).
  Stream<List<Shift>> watchShiftsForEmployee(
    String restaurantId,
    String employeeUid,
  ) {
    // TODO: query shifts where employeeUid == ... -> snapshots -> List<Shift>.
    throw UnimplementedError();
  }

  /// Tutti i turni del locale (calendario completo, vista Responsabile).
  Stream<List<Shift>> watchAllShifts(String restaurantId) {
    // TODO: snapshots() della collection shifts -> List<Shift>.
    throw UnimplementedError();
  }

  Future<void> createShift(String restaurantId, Shift shift) async {
    // TODO: add su restaurants/{rid}/shifts.
    throw UnimplementedError();
  }

  Future<void> updateShift(String restaurantId, Shift shift) async {
    // TODO: update su restaurants/{rid}/shifts/{shiftId}.
    throw UnimplementedError();
  }

  Future<void> deleteShift(String restaurantId, String shiftId) async {
    // TODO: delete su restaurants/{rid}/shifts/{shiftId}.
    throw UnimplementedError();
  }
}
