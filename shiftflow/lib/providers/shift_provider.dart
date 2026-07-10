import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/shift.dart';
import '../services/shift_service.dart';

/// Provider dei turni: espone alla UI la lista dei turni e lo stato di
/// caricamento, appoggiandosi a [ShiftService] per l'accesso a Firestore.
///
/// La lista arriva da uno stream (`snapshots()`): dopo la prima sottoscrizione
/// ogni modifica sul server (anche fatta da altri dispositivi) riemette la
/// lista aggiornata e la UI si ridisegna da sola.
class ShiftProvider extends ChangeNotifier {
  final ShiftService _shiftService;
  StreamSubscription<List<Shift>>? _subscription;

  /// Chiave della sottoscrizione attiva (per non risottoscrivere inutilmente
  /// alla stessa sorgente a ogni rebuild della UI).
  String? _watchKey;

  /// Locale della sottoscrizione attiva: serve alle operazioni CRUD.
  String? _restaurantId;

  ShiftProvider(this._shiftService);

  List<Shift> _shifts = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  List<Shift> get shifts => List.unmodifiable(_shifts);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  /// Inizia ad ascoltare tutti i turni del locale (vista Responsabile).
  void listenForRestaurant(String restaurantId) {
    _listen('all|$restaurantId', restaurantId,
        () => _shiftService.watchAllShifts(restaurantId));
  }

  /// Inizia ad ascoltare i turni del dipendente indicato (vista Dipendente).
  void listenForEmployee(String restaurantId, String employeeUid) {
    _listen('emp|$restaurantId|$employeeUid', restaurantId,
        () => _shiftService.watchShiftsForEmployee(restaurantId, employeeUid));
  }

  void _listen(
    String key,
    String restaurantId,
    Stream<List<Shift>> Function() source,
  ) {
    // Già in ascolto sulla stessa sorgente: niente da fare.
    if (_subscription != null && _watchKey == key) return;

    _subscription?.cancel();
    _watchKey = key;
    _restaurantId = restaurantId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = source().listen(
      (shifts) {
        _shifts = shifts;
        _isLoading = false;
        notifyListeners();
      },
      onError: (_) {
        // Uno stream Firestore che va in errore (es. permessi dopo il logout)
        // termina: azzeriamo la sottoscrizione così un futuro listen* riparte.
        _subscription?.cancel();
        _subscription = null;
        _isLoading = false;
        _errorMessage = 'Impossibile caricare i turni.';
        notifyListeners();
      },
    );
  }

  Future<bool> createShift(Shift shift) =>
      _mutate((rid) => _shiftService.createShift(rid, shift));

  Future<bool> updateShift(Shift shift) =>
      _mutate((rid) => _shiftService.updateShift(rid, shift));

  Future<bool> deleteShift(String shiftId) =>
      _mutate((rid) => _shiftService.deleteShift(rid, shiftId));

  /// Esegue una scrittura gestendo in un punto solo stato di salvataggio ed
  /// errori. La lista NON va aggiornata a mano: ci pensa lo stream.
  Future<bool> _mutate(Future<void> Function(String restaurantId) op) async {
    final rid = _restaurantId;
    if (rid == null) {
      _errorMessage = 'Nessun locale attivo.';
      notifyListeners();
      return false;
    }
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await op(rid);
      return true;
    } catch (_) {
      _errorMessage = 'Operazione non riuscita. Riprova.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
