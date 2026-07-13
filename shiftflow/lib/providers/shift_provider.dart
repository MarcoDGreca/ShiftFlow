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
  StreamSubscription<ShiftsView>? _subscription;

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
  bool _isFromCache = false;
  bool _hasPendingWrites = false;
  DateTime? _lastSyncedAt;

  List<Shift> get shifts => List.unmodifiable(_shifts);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  /// I turni mostrati arrivano dalla cache locale (tipicamente offline).
  bool get isFromCache => _isFromCache;

  /// Quando sono arrivati per l'ultima volta dati dal SERVER (non dalla cache).
  /// È la "data dell'ultimo aggiornamento" da mostrare offline (UC2-E1).
  DateTime? get lastSyncedAt => _lastSyncedAt;

  /// Ci sono scritture locali non ancora sincronizzate col server (§7.1).
  bool get hasPendingWrites => _hasPendingWrites;

  /// Il turno con questo id, o `null` se non presente tra quelli caricati.
  /// Usato per mostrare il turno collegato a una richiesta di cambio.
  Shift? byId(String id) {
    for (final shift in _shifts) {
      if (shift.id == id) return shift;
    }
    return null;
  }

  /// I turni che cadono nel giorno indicato (si confrontano solo
  /// anno/mese/giorno). Usato dal calendario mensile come `eventLoader`
  /// e per la lista del giorno selezionato.
  List<Shift> shiftsOn(DateTime day) {
    return _shifts
        .where(
          (s) =>
              s.date.year == day.year &&
              s.date.month == day.month &&
              s.date.day == day.day,
        )
        .toList();
  }

  /// Inizia ad ascoltare tutti i turni del locale (vista Responsabile).
  void listenForRestaurant(String restaurantId) {
    _listen(
      'all|$restaurantId',
      restaurantId,
      () => _shiftService.watchAllShifts(restaurantId),
    );
  }

  /// Inizia ad ascoltare i turni del dipendente indicato (vista Dipendente).
  void listenForEmployee(String restaurantId, String employeeUid) {
    _listen(
      'emp|$restaurantId|$employeeUid',
      restaurantId,
      () => _shiftService.watchShiftsForEmployee(restaurantId, employeeUid),
    );
  }

  void _listen(
    String key,
    String restaurantId,
    Stream<ShiftsView> Function() source,
  ) {
    // Già in ascolto sulla stessa sorgente: niente da fare.
    if (_subscription != null && _watchKey == key) return;

    _subscription?.cancel();
    _watchKey = key;
    _restaurantId = restaurantId;
    _isLoading = true;
    _errorMessage = null;
    // Sorgente nuova: azzeriamo il timestamp finché non arrivano dati freschi.
    _lastSyncedAt = null;
    notifyListeners();

    _subscription = source().listen(
      (view) {
        _shifts = view.shifts;
        _isFromCache = view.isFromCache;
        _hasPendingWrites = view.hasPendingWrites;
        // Dati confermati dal server (non dalla cache): aggiorniamo il momento
        // dell'ultima sincronizzazione da mostrare quando si va offline.
        if (!view.isFromCache) _lastSyncedAt = DateTime.now();
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

  /// I turni dei colleghi in servizio nello stesso turno del [shift] (UC2):
  /// altri turni del locale, lo stesso giorno, con orario che si sovrappone.
  /// Lettura singola: non modifica lo stato. Restituisce lista vuota se non
  /// c'è un locale attivo o non ci sono colleghi in servizio.
  Future<List<Shift>> coworkersFor(Shift shift) async {
    final rid = _restaurantId;
    if (rid == null) return [];
    final dayShifts = await _shiftService.fetchShiftsOnDate(rid, shift.date);
    return dayShifts
        .where(
          (s) =>
              s.id != shift.id &&
              s.employeeUid != shift.employeeUid &&
              ShiftService.timesOverlap(
                shift.startTime,
                shift.endTime,
                s.startTime,
                s.endTime,
              ),
        )
        .toList();
  }

  /// Cerca una sovrapposizione per il turno indicato (§7.3). Sola lettura:
  /// restituisce il turno in conflitto o `null`. Non modifica lo stato.
  Future<Shift?> findOverlap(Shift shift) async {
    final rid = _restaurantId;
    if (rid == null) return null;
    return _shiftService.findOverlapping(
      rid,
      employeeUid: shift.employeeUid,
      date: shift.date,
      startTime: shift.startTime,
      endTime: shift.endTime,
      excludeShiftId: shift.id.isEmpty ? null : shift.id,
    );
  }

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
