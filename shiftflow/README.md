# ShiftFlow

App mobile per la **gestione dei turni e delle richieste di permesso** nei
ristoranti indipendenti di piccole dimensioni (6–15 persone tra sala e cucina),
dove la pianificazione è responsabilità diretta del titolare o di un
responsabile di sala e non esiste una funzione HR strutturata.

ShiftFlow centralizza il calendario dei turni, rende tracciabile il ciclo di
richiesta/approvazione dei permessi e mostra a ogni persona la versione corrente
e affidabile del proprio turno, al posto di Excel, lavagna e messaggi in chat.

Progetto per il corso *Enterprise Mobile Application Development* (a.a.
2025/2026) — Marco Della Greca, Laurea Magistrale in Informatica, UNISA.
Documentazione di analisi: RAD, Lean Canvas e Pitch (documenti collegati).

## Due ruoli, due esperienze

- **Responsabile / Titolare** — costruisce il calendario del locale (crea,
  modifica, elimina turni, anche in serie), gestisce l'anagrafica del personale
  (aggiunta con creazione account, attivazione, disattivazione, rimozione) e
  approva o rifiuta le richieste.
- **Dipendente** — consulta i propri turni futuri, invia richieste di ferie,
  permesso o cambio turno e ne segue lo stato (in attesa, approvata, rifiutata,
  annullata, decaduta).

## Architettura

Quattro livelli, con dipendenze che puntano solo verso il basso. Firebase è
confinato ai Service: nessun import di Firebase risale sopra quel livello (RNF4).

```
Schermate / Widget  (Flutter)              lib/screens, lib/widgets
        │
Provider            (ChangeNotifier)       lib/providers
        │
Service             (logica di dominio,    lib/services
        │            unico punto Firebase)
Modelli & Firebase  (Auth, Firestore, FCM) lib/models, firestore.rules
```

### Modello dati Firestore

```
users/{uid}                                 profilo globale: ruolo, restaurantId
restaurants/{restaurantId}                  il locale (tenant)
   ├─ staff/{uid}                           anagrafica del personale (+ status)
   ├─ shifts/{shiftId}                      turni
   └─ leaveRequests/{requestId}             richieste di ferie/permesso/cambio
```

L'isolamento multi-tenant (RF9) e la privacy delle motivazioni tra colleghi
sono garantiti dalle `firestore.rules` (criterio RNF8), verificati dalla suite
in `firestore-tests/`.

## Stack

- **Flutter** — un'unica base di codice per Android 8.0+ e iOS 13+ (RNF5/RNF7).
- **Firebase** — Authentication (ruoli), Cloud Firestore (realtime + cache
  offline), Cloud Messaging (predisposizione token).
- **provider** per lo state management, **table_calendar** per il calendario
  mensile. Font Manrope impacchettato, design "simil-glass".

## Come avviare

Prerequisiti: Flutter SDK (Dart ≥ 3.11), un progetto Firebase configurato
(`lib/firebase_options.dart` generato con FlutterFire CLI).

```bash
flutter pub get
flutter run
```

## Test

Test Dart (utils, widget, modelli):

```bash
flutter analyze
flutter test
```

Test delle regole di sicurezza Firestore, su emulatore (RNF8):

```bash
cd firestore-tests
npm install
npm test
```

## Ambito dell'MVP

Fuori ambito, per scelta: rilevazione presenze/timbratura, calcolo retribuzioni,
verifica CCNL, multi-locale sotto un'unica titolarità, messaggistica interna e
invio di push (richiederebbe un backend fidato: i token FCM sono salvati come
prerequisito di un invio futuro). Vedi il RAD, §1.2.
