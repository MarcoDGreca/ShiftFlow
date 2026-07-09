import 'package:firebase_messaging/firebase_messaging.dart';

/// Wrapper attorno a Firebase Cloud Messaging (FCM).
///
/// NOTA IMPORTANTE sull'architettura delle notifiche (RF7):
/// - Lato client (questa app) possiamo RICEVERE notifiche, chiedere il permesso
///   e ottenere il token del dispositivo.
/// - INVIARE una notifica a un ALTRO utente (es. "nuovo turno assegnato") NON è
///   possibile in sicurezza dal client: serve un backend (es. Cloud Functions)
///   che, allo scattare di un evento su Firestore, invii il messaggio via FCM.
/// Per ora questi metodi sono stub: la scelta del backend è rimandata.
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Inizializza il servizio: permessi, handler dei messaggi in foreground/background.
  Future<void> init() async {
    // TODO: setup listener onMessage / onMessageOpenedApp.
    throw UnimplementedError();
  }

  /// Chiede all'utente il permesso di ricevere notifiche push.
  Future<void> requestPermission() async {
    // TODO: _messaging.requestPermission().
    throw UnimplementedError();
  }

  /// Token FCM del dispositivo corrente (identifica il device per l'invio).
  Future<String?> getToken() => _messaging.getToken();

  /// Salva il token del dispositivo associandolo all'utente, così un futuro
  /// backend saprà a quale device inviare. (Dove salvarlo va ancora deciso.)
  Future<void> saveTokenForUser(String uid) async {
    // TODO: persistere il token (es. users/{uid}.fcmTokens).
    throw UnimplementedError();
  }
}
