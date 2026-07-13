import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/leave_request.dart';
import '../services/leave_request_service.dart';

/// Provider delle richieste di permesso/cambio turno.
///
/// Stesso schema di [ShiftProvider]: sottoscrizione idempotente tramite una
/// chiave, operazioni di scrittura incanalate in `_mutate`, e la lista che si
/// aggiorna da sola tramite lo stream.
class LeaveRequestProvider extends ChangeNotifier {
  final LeaveRequestService _service;
  StreamSubscription<List<LeaveRequest>>? _subscription;
  String? _watchKey;
  String? _restaurantId;

  LeaveRequestProvider(this._service);

  List<LeaveRequest> _requests = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  List<LeaveRequest> get requests => List.unmodifiable(_requests);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  /// Numero di richieste ancora in attesa (per il badge del Responsabile).
  int get pendingCount =>
      _requests.where((r) => r.status == LeaveStatus.inAttesa).length;

  /// Le assenze (ferie/permessi) **approvate** che coprono il giorno indicato.
  /// Alimenta i marker e il dettaglio del giorno nei calendari. In base alla
  /// sottoscrizione attiva contiene i soli turni del dipendente (vista propria)
  /// o quelli di tutto il locale (vista responsabile).
  List<LeaveRequest> approvedLeavesOn(DateTime day) {
    return _requests
        .where(
          (r) =>
              r.status == LeaveStatus.approvata &&
              (r.isFerie || r.isPermesso) &&
              r.coversDay(day),
        )
        .toList();
  }

  /// Ascolta le richieste del singolo dipendente (storico personale).
  void listenForEmployee(String restaurantId, String employeeUid) {
    _listen(
      'emp|$restaurantId|$employeeUid',
      restaurantId,
      () => _service.watchRequestsForEmployee(restaurantId, employeeUid),
    );
  }

  /// Ascolta tutte le richieste del locale (coda del Responsabile).
  void listenForRestaurant(String restaurantId) {
    _listen(
      'all|$restaurantId',
      restaurantId,
      () => _service.watchAllRequests(restaurantId),
    );
  }

  void _listen(
    String key,
    String restaurantId,
    Stream<List<LeaveRequest>> Function() source,
  ) {
    if (_subscription != null && _watchKey == key) return;

    _subscription?.cancel();
    _watchKey = key;
    _restaurantId = restaurantId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = source().listen(
      (requests) {
        _requests = requests;
        _isLoading = false;
        notifyListeners();
      },
      onError: (_) {
        _subscription?.cancel();
        _subscription = null;
        _isLoading = false;
        _errorMessage = 'Impossibile caricare le richieste.';
        notifyListeners();
      },
    );
  }

  /// Il dipendente invia una nuova richiesta.
  Future<bool> createRequest(LeaveRequest request) =>
      _mutate((rid) => _service.createRequest(rid, request));

  /// Il responsabile approva o rifiuta una richiesta. In caso di approvazione
  /// può anche agire sul turno collegato (RF6): vedi [ShiftResolution].
  Future<bool> resolve(
    String requestId, {
    required bool approved,
    required String resolvedByUid,
    String? relatedShiftId,
    ShiftResolution shiftResolution = ShiftResolution.keep,
    String? reassignToUid,
  }) => _mutate(
    (rid) => _service.resolveRequest(
      rid,
      requestId,
      approved: approved,
      resolvedByUid: resolvedByUid,
      relatedShiftId: relatedShiftId,
      shiftResolution: shiftResolution,
      reassignToUid: reassignToUid,
    ),
  );

  /// Il dipendente annulla una propria richiesta ancora in attesa.
  Future<bool> cancel(String requestId, {required String employeeUid}) =>
      _mutate(
        (rid) =>
            _service.cancelRequest(rid, requestId, employeeUid: employeeUid),
      );

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
    } on LeaveRequestException catch (e) {
      // Errore "atteso" (es. richiesta già decisa): mostriamo il suo messaggio.
      _errorMessage = e.message;
      return false;
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
