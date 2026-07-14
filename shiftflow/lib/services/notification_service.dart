import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../core/constants/app_constants.dart';

/// Handler dei messaggi ricevuti quando l'app è in background o terminata.
///
/// Deve essere una funzione top-level (o statica) annotata `@pragma`: il
/// framework la esegue in un isolate separato, quindi non può essere un metodo
/// d'istanza. Qui la teniamo minimale: se il server invia una notifica di tipo
/// "notification", il sistema operativo la mostra da solo.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Volutamente vuoto: nessuna logica pesante in background per l'MVP.
}

/// Wrapper attorno a Firebase Cloud Messaging (FCM) — livello Services.
///
/// COSA COPRE (parte fattibile lato client, in-stack):
///  - chiedere il permesso di ricevere notifiche;
///  - ottenere e salvare il token del dispositivo in `users/{uid}.fcmTokens`;
///  - ricevere i messaggi in foreground/background.
///
/// COSA NON COPRE: l'INVIO di una push a un altro utente (es. "nuovo turno").
/// Richiede un componente server fidato (es. Cloud Functions), fuori dallo
/// stack dichiarato: la scelta è rimandata. Salvare i token qui è comunque il
/// prerequisito di qualsiasi invio futuro.
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Registra l'handler dei messaggi in background. Va chiamato in `main`,
  /// prima di `runApp`. Sta qui (nel Service) così l'import di
  /// `firebase_messaging` non risale sopra il livello Services (RNF4).
  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  /// Configura le notifiche per l'utente autenticato: permesso, ascolto dei
  /// messaggi in foreground e salvataggio del token (con i refresh successivi).
  ///
  /// Non lancia mai: un errore qui (permesso negato, FCM non disponibile su
  /// alcune piattaforme/emulatori) non deve compromettere il login.
  Future<void> setUpForUser(String uid) async {
    try {
      await requestPermission();

      // Messaggi ricevuti mentre l'app è in primo piano.
      FirebaseMessaging.onMessage.listen((message) {
        // Per mostrare qui una notifica di sistema servirebbe il pacchetto
        // flutter_local_notifications (dipendenza da concordare). Per ora
        // lasciamo il gancio pronto.
      });

      final token = await _messaging.getToken();
      if (token != null) await _saveToken(uid, token);

      // Il token può cambiare nel tempo: teniamolo aggiornato.
      _messaging.onTokenRefresh.listen((newToken) => _saveToken(uid, newToken));
    } catch (_) {
      // Ignorato di proposito: le notifiche sono "best effort".
    }
  }

  /// Chiede all'utente il permesso di ricevere notifiche push.
  Future<void> requestPermission() async {
    await _messaging.requestPermission();
  }

  /// Token FCM del dispositivo corrente (identifica il device per l'invio).
  Future<String?> getToken() => _messaging.getToken();

  /// Aggiunge il token all'elenco dei device dell'utente, senza duplicati.
  Future<void> _saveToken(String uid, String token) async {
    await _db.collection(FirestoreCollections.users).doc(uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  /// Rimuove il token di questo dispositivo al logout, così non riceve più le
  /// push destinate all'utente che è uscito.
  Future<void> removeTokenForUser(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await _db.collection(FirestoreCollections.users).doc(uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
    } catch (_) {
      // Best effort: se fallisce non blocchiamo il logout.
    }
  }
}
