import 'package:flutter/foundation.dart';

import '../models/shift.dart';
import '../services/shift_service.dart';

/// Provider dei turni: espone alla UI la lista dei turni e lo stato di
/// caricamento, appoggiandosi a [ShiftService] per l'accesso a Firestore.
class ShiftProvider extends ChangeNotifier {
  // ignore: unused_field  (usato quando implementeremo le sottoscrizioni)
  final ShiftService _shiftService;

  ShiftProvider(this._shiftService);

  List<Shift> _shifts = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Shift> get shifts => List.unmodifiable(_shifts);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Inizia ad ascoltare i turni del dipendente indicato.
  void listenForEmployee(String restaurantId, String employeeUid) {
    // TODO: sottoscrivere _shiftService.watchShiftsForEmployee(...).
    throw UnimplementedError();
  }

  /// Inizia ad ascoltare tutti i turni del locale (vista Responsabile).
  void listenForRestaurant(String restaurantId) {
    // TODO: sottoscrivere _shiftService.watchAllShifts(...).
    throw UnimplementedError();
  }
}
