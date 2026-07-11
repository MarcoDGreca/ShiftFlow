import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/restaurant_service.dart';

/// Provider dell'anagrafica personale del locale.
///
/// Si appoggia a due service: [RestaurantService] per elenco e rimozione,
/// [AuthService] per l'aggiunta di un dipendente (che comporta la creazione
/// del suo account Firebase Auth).
class StaffProvider extends ChangeNotifier {
  final RestaurantService _restaurantService;
  final AuthService _authService;
  StreamSubscription<List<AppUser>>? _subscription;
  String? _restaurantId;

  StaffProvider(this._restaurantService, this._authService);

  List<AppUser> _staff = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  List<AppUser> get staff => List.unmodifiable(_staff);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  /// Il membro dello staff con questo uid, o `null` se non presente.
  AppUser? byUid(String uid) {
    for (final member in _staff) {
      if (member.uid == uid) return member;
    }
    return null;
  }

  /// Ascolta l'elenco del personale del locale.
  void listenForRestaurant(String restaurantId) {
    if (_subscription != null && _restaurantId == restaurantId) return;

    _subscription?.cancel();
    _restaurantId = restaurantId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _restaurantService.watchStaff(restaurantId).listen(
      (staff) {
        _staff = staff;
        _isLoading = false;
        notifyListeners();
      },
      onError: (_) {
        _subscription?.cancel();
        _subscription = null;
        _isLoading = false;
        _errorMessage = 'Impossibile caricare il personale.';
        notifyListeners();
      },
    );
  }

  /// Crea l'account di un nuovo dipendente e lo aggiunge all'anagrafica.
  /// La lista si aggiorna da sola tramite lo stream.
  Future<bool> addDipendente({
    required String name,
    required String email,
    required String password,
  }) async {
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
      await _authService.createDipendente(
        email: email,
        password: password,
        name: name,
        restaurantId: rid,
      );
      return true;
    } on AuthException catch (e) {
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

  /// Attiva o disattiva un dipendente. La lista si aggiorna da sola (stream).
  Future<bool> setActive(String uid, {required bool active}) async {
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
      await _restaurantService.setStaffActive(rid, uid, active: active);
      return true;
    } catch (_) {
      _errorMessage = 'Operazione non riuscita. Riprova.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Rimuove un dipendente dall'anagrafica del locale.
  Future<bool> removeDipendente(String uid) async {
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
      await _restaurantService.removeStaff(rid, uid);
      return true;
    } catch (_) {
      _errorMessage = 'Rimozione non riuscita. Riprova.';
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
