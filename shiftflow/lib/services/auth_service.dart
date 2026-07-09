import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/app_constants.dart';
import '../models/app_user.dart';
import '../models/restaurant.dart';

/// Eccezione "di dominio" per gli errori di autenticazione.
///
/// Serve a NON far uscire il tipo `FirebaseAuthException` (di firebase_auth) dal
/// livello Service: il Provider cattura questa eccezione "neutra" con un
/// messaggio già pronto per l'utente, senza dover importare firebase_auth.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

/// Wrapper attorno a Firebase Auth + al documento `users/{uid}` su Firestore.
///
/// È l'UNICO punto (con gli altri Service) che parla direttamente con Firebase:
/// i Provider chiamano questi metodi, i widget chiamano i Provider.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream del PROFILO applicativo dell'utente loggato (`AppUser`), o `null`
  /// se non c'è nessuna sessione o il profilo non esiste (ancora).
  ///
  /// È *reattivo su due livelli*:
  ///  - ascolta i cambi di sessione (`authStateChanges`);
  ///  - quando c'è un utente, ascolta in tempo reale il suo documento
  ///    `users/{uid}` con `snapshots()`.
  ///
  /// Perché `snapshots()` e non una lettura singola? Durante la registrazione
  /// l'utente viene loggato PRIMA che il documento profilo esista: ascoltando
  /// il documento, appena lo creiamo lo stream riemette da solo e l'app passa
  /// alla home, senza race condition.
  ///
  /// Nota: implementiamo a mano il "cambia sorgente interna quando cambia
  /// l'utente" (in RxDart si chiamerebbe `switchMap`) con uno StreamController,
  /// per non aggiungere pacchetti esterni.
  Stream<AppUser?> userChanges() {
    final controller = StreamController<AppUser?>();
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? docSub;
    late final StreamSubscription<User?> authSub;

    authSub = _auth.authStateChanges().listen((user) {
      // A ogni cambio di sessione, smettiamo di ascoltare il documento vecchio.
      docSub?.cancel();
      docSub = null;

      if (user == null) {
        controller.add(null); // logout / nessuna sessione
      } else {
        docSub = _db
            .collection(FirestoreCollections.users)
            .doc(user.uid)
            .snapshots()
            .listen(
          (doc) => controller.add(doc.exists ? AppUser.fromFirestore(doc) : null),
          onError: (_) => controller.add(null),
        );
      }
    });

    // Quando nessuno ascolta più lo stream, chiudiamo le sottoscrizioni.
    controller.onCancel = () async {
      await docSub?.cancel();
      await authSub.cancel();
    };

    return controller.stream;
  }

  /// L'utente Firebase attualmente loggato (o `null`). Uso interno/tecnico.
  User? get currentAuthUser => _auth.currentUser;

  /// Effettua il login con email/password.
  ///
  /// Non restituisce nulla: il profilo aggiornato arriva tramite [userChanges].
  /// In caso di credenziali errate lancia una [AuthException] con messaggio
  /// leggibile.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFromCode(e.code));
    }
  }

  /// Registra un nuovo RESPONSABILE creando, in quest'ordine:
  ///  1. l'account Firebase Auth (che effettua subito il login);
  ///  2. il documento `users/{uid}` — DEVE essere primo, perché le regole di
  ///     sicurezza del locale controllano il ruolo leggendo proprio questo doc;
  ///  3. il documento del locale `restaurants/{rid}`;
  ///  4. il documento `staff/{uid}` (il titolare è anche parte dell'anagrafica).
  ///
  /// L'esito (l'ingresso nella home) arriva tramite lo stream [userChanges].
  Future<void> registerResponsabile({
    required String email,
    required String password,
    required String name,
    required String restaurantName,
    required String restaurantAddress,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;

      // `doc()` senza argomenti genera un ID nuovo SENZA scrivere nulla: così
      // conosciamo il restaurantId in anticipo e lo mettiamo nel profilo utente.
      final restaurantRef =
          _db.collection(FirestoreCollections.restaurants).doc();
      final restaurantId = restaurantRef.id;

      // 1) users/{uid}
      final appUser = AppUser(
        uid: uid,
        restaurantId: restaurantId,
        role: UserRoles.responsabile,
        name: name,
        email: email,
      );
      await _db
          .collection(FirestoreCollections.users)
          .doc(uid)
          .set(appUser.toFirestore());

      // 2) restaurants/{rid}
      final restaurant = Restaurant(
        id: restaurantId,
        name: restaurantName,
        address: restaurantAddress,
        ownerUid: uid,
      );
      await restaurantRef.set(restaurant.toFirestore());

      // 3) staff/{uid}
      await restaurantRef
          .collection(FirestoreCollections.staff)
          .doc(uid)
          .set({
        'name': name,
        'email': email,
        'role': UserRoles.responsabile,
        'status': StaffStatus.attivo,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFromCode(e.code));
    } catch (_) {
      // Es. una scrittura Firestore rifiutata dalle regole.
      throw const AuthException('Registrazione non riuscita. Riprova.');
    }
  }

  /// Legge il documento `users/{uid}` e lo converte in [AppUser].
  /// Restituisce `null` se il documento non esiste.
  Future<AppUser?> fetchUserDoc(String uid) async {
    final doc =
        await _db.collection(FirestoreCollections.users).doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc);
  }

  Future<void> signOut() => _auth.signOut();

  /// Traduce i codici d'errore di Firebase Auth in messaggi per l'utente.
  String _messageFromCode(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Email non valida.';
      case 'user-disabled':
        return 'Questo account è stato disabilitato.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email o password non corretti.';
      case 'email-already-in-use':
        return 'Questa email è già registrata.';
      case 'weak-password':
        return 'Password troppo debole (almeno 6 caratteri).';
      case 'operation-not-allowed':
        return 'Metodo di accesso non abilitato.';
      case 'too-many-requests':
        return 'Troppi tentativi. Riprova più tardi.';
      case 'network-request-failed':
        return 'Problema di rete. Controlla la connessione.';
      default:
        return 'Operazione non riuscita. Riprova.';
    }
  }
}
