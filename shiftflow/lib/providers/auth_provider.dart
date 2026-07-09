import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

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
  StreamSubscription<AppUser?>? _subscription;

  AuthProvider(this._authService) {
    // Ci mettiamo in ascolto: a ogni login/logout (anche al riavvio dell'app,
    // perché Firebase mantiene la sessione) aggiorniamo lo stato.
    _subscription = _authService.userChanges().listen(_onUserChanged);
  }

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _currentUser;
  bool _isSubmitting = false;
  String? _errorMessage;

  AuthStatus get status => _status;
  AppUser? get currentUser => _currentUser;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  bool get isResponsabile => _currentUser?.isResponsabile ?? false;

  void _onUserChanged(AppUser? user) {
    _currentUser = user;
    _status =
        user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated;
    notifyListeners();
  }

  /// Esegue il login. Aggiorna `isSubmitting`/`errorMessage`; l'esito positivo
  /// (utente + status) arriva tramite lo stream, non da qui.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
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

  Future<void> signOut() => _authService.signOut();

  @override
  void dispose() {
    // Importante: chiudere la sottoscrizione per evitare memory leak.
    _subscription?.cancel();
    super.dispose();
  }
}
