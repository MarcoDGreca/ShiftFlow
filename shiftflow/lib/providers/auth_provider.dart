import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

/// Stato di autenticazione, usato dalla UI per decidere cosa mostrare.
/// `unknown` = non sappiamo ancora (all'avvio, prima del primo evento).
enum AuthStatus { unknown, authenticated, unauthenticated }

/// Provider dell'autenticazione: fa da ponte tra la UI e [AuthService].
///
/// Ascolta lo stream `userChanges()` del service (che emette un [AppUser] o
/// `null`) e ne ricava lo [status]. Espone anche lo stato del form di login
/// ([isSubmitting], [errorMessage]). I widget leggono questi getter e chiamano
/// [signIn]/[signOut]; non toccano mai [AuthService] direttamente.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final NotificationService _notificationService;
  StreamSubscription<AppUser?>? _subscription;

  /// Osservazione dello stato del membro nell'anagrafica (attivo/disattivato).
  StreamSubscription<String?>? _staffSub;
  String? _staffWatchUid;

  /// uid per cui abbiamo già configurato le notifiche (evita di rifarlo a
  /// ogni emissione dello stream).
  String? _fcmUid;

  AuthProvider(this._authService, this._notificationService) {
    // Ci mettiamo in ascolto: a ogni login/logout (anche al riavvio dell'app,
    // perché Firebase mantiene la sessione) aggiorniamo lo stato.
    _subscription = _authService.userChanges().listen(_onUserChanged);
  }

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _currentUser;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _isDeactivated = false;

  AuthStatus get status => _status;
  AppUser? get currentUser => _currentUser;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  bool get isResponsabile => _currentUser?.isResponsabile ?? false;

  /// True se il membro risulta DISATTIVATO nell'anagrafica: pur essendo ancora
  /// autenticato, l'app deve negargli l'accesso alle funzioni (UC2-E2).
  bool get isDeactivated => _isDeactivated;

  void _onUserChanged(AppUser? user) {
    _currentUser = user;
    _status = user == null
        ? AuthStatus.unauthenticated
        : AuthStatus.authenticated;

    // (Ri)avvia l'osservazione dello stato "attivo/disattivato" del membro.
    _watchStaffStatus(user);

    notifyListeners();

    // Configura le notifiche una volta per utente. Operazione di rete "best
    // effort": non attendiamo né blocchiamo lo stato dell'auth su di essa.
    if (user != null && user.uid != _fcmUid) {
      _fcmUid = user.uid;
      unawaited(_notificationService.setUpForUser(user.uid));
    } else if (user == null) {
      _fcmUid = null;
    }
  }

  /// Osserva lo stato del membro nell'anagrafica per bloccare un dipendente
  /// disattivato (UC2-E2). Blocca solo su "disattivato" esplicito: un documento
  /// staff assente non blocca (evita falsi positivi durante il caricamento).
  void _watchStaffStatus(AppUser? user) {
    // Utente cambiato (o logout): chiudiamo l'osservazione precedente e
    // ripartiamo dallo stato "non disattivato".
    if (user == null || user.uid != _staffWatchUid) {
      _staffSub?.cancel();
      _staffSub = null;
      _staffWatchUid = null;
      _isDeactivated = false;
    }
    if (user == null) return;
    if (_staffWatchUid == user.uid) return; // già in ascolto su questo utente

    _staffWatchUid = user.uid;
    _staffSub = _authService
        .watchStaffStatus(user.restaurantId, user.uid)
        .listen((status) {
          final deactivated = status == StaffStatus.disattivato;
          if (deactivated != _isDeactivated) {
            _isDeactivated = deactivated;
            notifyListeners();
          }
        });
  }

  /// Esegue il login. Aggiorna `isSubmitting`/`errorMessage`; l'esito positivo
  /// (utente + status) arriva tramite lo stream, non da qui.
  Future<void> signIn({required String email, required String password}) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.signIn(email: email, password: password);
    } on AuthException catch (e) {
      _errorMessage = e.message;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Registra un nuovo Responsabile (crea account + locale + profilo).
  /// Ritorna `true` se è andata a buon fine. L'ingresso nella home avviene
  /// tramite lo stream, come per il login.
  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String restaurantName,
    required String restaurantAddress,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.registerResponsabile(
        email: email,
        password: password,
        name: name,
        restaurantName: restaurantName,
        restaurantAddress: restaurantAddress,
      );
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Azzera l'eventuale messaggio d'errore (es. passando da login a registrazione).
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    // Rimuoviamo il token FINCHÉ siamo ancora autenticati (le regole
    // permettono la scrittura solo sul proprio documento).
    final uid = _currentUser?.uid;
    if (uid != null) {
      await _notificationService.removeTokenForUser(uid);
    }
    await _authService.signOut();
  }

  @override
  void dispose() {
    // Importante: chiudere le sottoscrizioni per evitare memory leak.
    _subscription?.cancel();
    _staffSub?.cancel();
    super.dispose();
  }
}
