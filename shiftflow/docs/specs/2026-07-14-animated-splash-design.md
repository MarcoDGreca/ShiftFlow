# Splash animata all'avvio — Design

Data: 2026-07-14
Stato: approvato

## Obiettivo

All'apertura dell'app, una breve animazione di brand al posto della splash
statica attuale: l'onda a "S" del logo si traccia da sola come una pennellata,
poi compaiono le onde-eco e il nome "ShiftFlow". L'animazione si vede sempre
per intero (~1,5 s) prima di entrare in home o login.

## Scelte fatte

- **Stile**: l'onda si disegna progressivamente (path tracing), poi eco e
  titolo in dissolvenza. Niente Lottie/Rive: tutto con `CustomPaint` +
  `PathMetrics`, zero pacchetti nuovi (coerente con lo stile del progetto).
- **Durata**: animazione sempre completa. `AuthGate` entra in home/login solo
  quando l'animazione è finita **e** lo stato di autenticazione è noto. Se a
  fine animazione Firebase non ha ancora risposto, compare lo spinner sotto il
  logo (come oggi) finché lo stato non arriva.
- **Accessibilità**: con `MediaQuery.disableAnimations` attivo si salta la
  pennellata: logo statico e ingresso appena lo stato è noto (comportamento
  attuale).

## Timeline (totale ~1,5 s)

| Fase | Intervallo | Effetto |
|---|---|---|
| Onda | 0 – 0,9 s | il tratto a "S" si traccia (easeInOut) |
| Eco | 0,6 – 1,1 s | le due onde-eco sfumano in vista |
| Titolo | 0,9 – 1,4 s | "ShiftFlow" fade-in + leggera salita |

## Componenti

1. **`lib/core/branding/shiftflow_logo.dart`** — `ShiftFlowLogoPainter` riceve
   un nuovo parametro `progress` (0..1, default `1.0`):
   - trima il tratto dell'onda principale con `PathMetrics.extractPath`;
   - lega l'opacità delle eco alla finestra 0,6–1,1 s (normalizzata su
     `progress`);
   - con `progress: 1.0` il render resta IDENTICO a oggi (icona app, UI,
     versione monochrome non cambiano). `shouldRepaint` considera `progress`.
2. **`lib/screens/shared/animated_splash_screen.dart`** (nuovo) —
   `AnimatedSplashScreen`, stateful:
   - possiede l'`AnimationController` (~1,5 s) con `TickerProviderStateMixin`;
   - layout identico alla splash attuale di `AuthGate` (AppBackground, logo
     120, titolo, spinner) ma animato;
   - parametri: `onFinished` (callback), `showSpinner` (bool: true quando
     l'animazione è finita ma lo stato è ancora `unknown`);
   - se `MediaQuery.disableAnimations` è true: nessuna animazione, chiama
     `onFinished` subito (post-frame).
3. **`lib/screens/shared/auth_gate.dart`** — da `StatelessWidget` a
   `StatefulWidget` con flag `_introDone`:
   - mostra `AnimatedSplashScreen` finché `!_introDone || status == unknown`;
   - `onFinished` ⇒ `setState(_introDone = true)`;
   - il ramo `authenticated`/`unauthenticated` resta invariato (incluso il
     blocco `isDeactivated`).

## Flusso

1. Avvio app → splash nativa (invariata) → `AuthGate`.
2. `AuthGate`: `_introDone == false` → `AnimatedSplashScreen` parte.
3. A fine corsa: `onFinished` → se lo stato è noto si entra subito in
   home/login; se è ancora `unknown` la splash resta con lo spinner visibile.
4. Riduzione animazioni attiva → si comporta come la splash statica di oggi.

## Errori e casi limite

- Hot reload / rebuild di `AuthGate`: il flag `_introDone` vive nello State,
  l'animazione non riparte a ogni rebuild del provider.
- Logout durante l'uso: `status` torna `unauthenticated` ma `_introDone` è già
  true → si va dritti al login, nessuna splash ripetuta.
- Il controller va fatto `dispose()` correttamente.

## Test

- Widget test di `AnimatedSplashScreen`:
  - con tempo simulato (`tester.pump(...)`) `onFinished` scatta a fine corsa;
  - con `disableAnimations: true` scatta subito;
  - `showSpinner: true` mostra il `CircularProgressIndicator`.
- Il painter con `progress: 1.0` non cambia: i test esistenti (inclusa la
  generazione icona in `test/tools/`) devono restare verdi.
- `flutter analyze` pulito.

## Fuori scope

- Modifiche alla splash nativa (`flutter_native_splash`).
- Animazioni in altre schermate.
