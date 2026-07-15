# Splash Animata Implementation Plan

**Goal:** Splash animata all'avvio: l'onda del logo si traccia come una pennellata, poi eco e titolo in dissolvenza (~1,5 s, sempre completa) prima di entrare in home/login.

**Architecture:** Il painter esistente del logo riceve un parametro `progress` (0..1) che trima il tratto con `PathMetrics` e sfuma le eco; un nuovo widget `AnimatedSplashScreen` possiede l'`AnimationController` e chiama `onFinished` a fine corsa; `AuthGate` diventa stateful e tiene la splash finché intro e stato auth non sono entrambi pronti.

**Tech Stack:** Flutter puro (CustomPaint, PathMetrics, AnimationController). NESSUN pacchetto nuovo.

**Spec:** `docs/specs/2026-07-14-animated-splash-design.md`

## Global Constraints

- Nessuna dipendenza aggiunta a `pubspec.yaml`.
- Con `progress: 1.0` (default) il logo deve renderizzare IDENTICO a oggi: icona app e ogni uso esistente non cambiano.
- Commenti nel codice in italiano, stile del progetto (spiegano il perché).
- Accessibilità: con `MediaQuery.disableAnimations` la splash salta l'animazione e chiama subito `onFinished`.
- Package Dart: `shiftflow` (import nei test: `package:shiftflow/...`).
- Ogni task si chiude con `flutter analyze` pulito e `flutter test` verde.

---

### Task 1: Parametro `progress` sul painter del logo

**Files:**
- Modify: `lib/core/branding/shiftflow_logo.dart`
- Test: `test/widgets/shiftflow_logo_test.dart` (nuovo)

**Interfaces:**
- Produces: `ShiftFlowLogo({double progress = 1.0, ...})` e
  `ShiftFlowLogoPainter({double progress = 1.0, ...})`. Semantica di
  `progress` (0..1, frazione della timeline della splash): l'onda principale
  si traccia da 0.0 a 0.6; le eco sfumano in vista da 0.4 a 0.75; a 1.0 il
  render è identico alla versione statica attuale. Task 2 costruisce
  `ShiftFlowLogo(size: 120, progress: controller.value)`.

- [ ] **Step 1: Scrivere i test (falliranno: `progress` non esiste ancora)**

Creare `test/widgets/shiftflow_logo_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiftflow/core/branding/shiftflow_logo.dart';

void main() {
  testWidgets('renderizza senza errori a vari progress', (tester) async {
    for (final p in [0.0, 0.3, 0.65, 1.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: ShiftFlowLogo(size: 64, progress: p)),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'progress $p');
    }
  });

  testWidgets('renderizza senza errori anche in versione monochrome',
      (tester) async {
    for (final p in [0.0, 0.5, 1.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: ShiftFlowLogo(size: 64, monochrome: true, progress: p),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'progress $p');
    }
  });

  test('shouldRepaint scatta quando cambia progress', () {
    const prima = ShiftFlowLogoPainter(progress: 0.3);
    const dopo = ShiftFlowLogoPainter(progress: 0.6);
    expect(dopo.shouldRepaint(prima), isTrue);
  });

  test('shouldRepaint NON scatta a parità di parametri', () {
    const prima = ShiftFlowLogoPainter();
    const dopo = ShiftFlowLogoPainter();
    expect(dopo.shouldRepaint(prima), isFalse);
  });
}
```

- [ ] **Step 2: Verificare che falliscano**

Run: `flutter test test/widgets/shiftflow_logo_test.dart`
Expected: errore di COMPILAZIONE (`No named parameter with the name 'progress'`).

- [ ] **Step 3: Implementare `progress` nel painter e nel widget**

In `lib/core/branding/shiftflow_logo.dart`.

Al widget `ShiftFlowLogo`: aggiungere il campo e passarlo al painter.

```dart
class ShiftFlowLogo extends StatelessWidget {
  final double size;

  /// Versione a un solo colore (serve per l'icona "a tema" di Android 13+
  /// e ovunque serva una silhouette).
  final bool monochrome;
  final Color monochromeColor;

  /// Avanzamento del disegno (0..1) per la splash animata: l'onda si traccia
  /// nella prima parte, le eco compaiono dopo. Con 1.0 (default) il logo è
  /// quello statico di sempre.
  final double progress;

  const ShiftFlowLogo({
    super.key,
    this.size = 64,
    this.monochrome = false,
    this.monochromeColor = Colors.white,
    this.progress = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logo ShiftFlow',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: ShiftFlowLogoPainter(
          monochrome: monochrome,
          monochromeColor: monochromeColor,
          progress: progress,
        ),
      ),
    );
  }
}
```

Al painter: campo `progress`, costanti di fase, helper `_trim`, e uso nelle
tre `drawPath`. Il metodo `paint` diventa:

```dart
class ShiftFlowLogoPainter extends CustomPainter {
  final bool monochrome;
  final Color monochromeColor;

  /// Vedi [ShiftFlowLogo.progress].
  final double progress;

  const ShiftFlowLogoPainter({
    this.monochrome = false,
    this.monochromeColor = Colors.white,
    this.progress = 1.0,
  });

  // Fasi della timeline, come frazioni di [progress]: prima si traccia
  // l'onda, poi (in parte sovrapposte) compaiono le eco.
  static const _waveEnd = 0.6;
  static const _echoStart = 0.4;
  static const _echoEnd = 0.75;

  /// Il tratto [path] fermato alla frazione [t] della sua lunghezza:
  /// è ciò che dà l'effetto "pennellata che si disegna".
  Path _trim(Path path, double t) {
    if (t >= 1.0) return path;
    final metric = path.computeMetrics().first;
    return metric.extractPath(0, metric.length * t);
  }
```

(le funzioni `_wave` e `_stroke` restano identiche) e in `paint`:

```dart
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;

    // Quanto è tracciata l'onda e quanto sono visibili le eco, derivati
    // dall'unico progress: così il chiamante anima un solo valore.
    final waveT = Curves.easeInOut.transform(
      (progress / _waveEnd).clamp(0.0, 1.0),
    );
    final echoT =
        ((progress - _echoStart) / (_echoEnd - _echoStart)).clamp(0.0, 1.0);

    if (monochrome) {
      // Silhouette pulita: solo l'onda principale, un filo più spessa.
      // Le eco dello stesso colore si fonderebbero in una macchia.
      if (waveT > 0) {
        canvas.drawPath(
          _trim(_wave(s, 0, 0), waveT),
          _stroke(0.17 * s)..color = monochromeColor,
        );
      }
      return;
    }

    if (echoT > 0) {
      // Eco superiore: più chiara e sottile, come un riflesso.
      canvas.drawPath(
        _wave(s, -0.075, -0.075),
        _stroke(0.055 * s)
          ..color = AppColors.emerald300.withValues(alpha: 0.85 * echoT),
      );
      // Eco inferiore: più scura, come un'ombra dell'onda.
      canvas.drawPath(
        _wave(s, 0.075, 0.075),
        _stroke(0.055 * s)
          ..color = AppColors.emerald700.withValues(alpha: 0.75 * echoT),
      );
    }

    // Onda principale con il gradiente del brand.
    if (waveT > 0) {
      canvas.drawPath(
        _trim(_wave(s, 0, 0), waveT),
        _stroke(0.15 * s)
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.emerald300,
              AppColors.emerald600,
              AppColors.emerald900,
            ],
          ).createShader(Offset.zero & size),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ShiftFlowLogoPainter oldDelegate) =>
      oldDelegate.monochrome != monochrome ||
      oldDelegate.monochromeColor != monochromeColor ||
      oldDelegate.progress != progress;
}
```

- [ ] **Step 4: Verificare che i test passino (tutti, non solo i nuovi)**

Run: `flutter analyze && flutter test`
Expected: analyze pulito; tutti i test PASS (compresi quelli esistenti in
`test/tools/`, che usano il default `progress: 1.0`).

- [ ] **Step 5: Commit**

```bash
git add lib/core/branding/shiftflow_logo.dart test/widgets/shiftflow_logo_test.dart
git commit -m "feat: parametro progress sul logo per la splash animata"
```

---

### Task 2: Widget `AnimatedSplashScreen`

**Files:**
- Create: `lib/screens/shared/animated_splash_screen.dart`
- Test: `test/screens/animated_splash_screen_test.dart` (nuovo, creare anche la cartella)

**Interfaces:**
- Consumes: `ShiftFlowLogo(size: 120, progress: <0..1>)` dal Task 1;
  `AppBackground({child})`, `AppSpacing.lg`/`AppSpacing.xl` esistenti.
- Produces: `AnimatedSplashScreen({required VoidCallback onFinished, bool showSpinner = false})`.
  `onFinished` viene chiamata UNA volta, in un post-frame callback, quando
  l'animazione (~1,5 s) è conclusa — subito, se `disableAnimations` è attivo.
  Task 3 la usa così: `AnimatedSplashScreen(showSpinner: _introDone, onFinished: ...)`.

- [ ] **Step 1: Scrivere i test (falliranno: il file non esiste)**

Creare `test/screens/animated_splash_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiftflow/screens/shared/animated_splash_screen.dart';

void main() {
  testWidgets('chiama onFinished quando l\'animazione termina',
      (tester) async {
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedSplashScreen(onFinished: () => finished = true),
      ),
    );

    // A metà corsa non deve ancora aver chiamato il callback.
    await tester.pump(const Duration(milliseconds: 800));
    expect(finished, isFalse);

    // Oltre la durata totale (~1,5 s) + il post-frame callback.
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(finished, isTrue);
  });

  testWidgets('con "riduci animazioni" attivo finisce subito', (tester) async {
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: AnimatedSplashScreen(onFinished: () => finished = true),
        ),
      ),
    );
    await tester.pump(); // post-frame callback
    expect(finished, isTrue);
  });

  testWidgets('mostra lo spinner solo se richiesto', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedSplashScreen(onFinished: () {}, showSpinner: true),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(home: AnimatedSplashScreen(onFinished: () {})),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('mostra logo e titolo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AnimatedSplashScreen(onFinished: () {})),
    );
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('ShiftFlow'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Verificare che falliscano**

Run: `flutter test test/screens/animated_splash_screen_test.dart`
Expected: errore di compilazione (URI inesistente).

- [ ] **Step 3: Implementare il widget**

Creare `lib/screens/shared/animated_splash_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../core/branding/shiftflow_logo.dart';
import '../../core/theme/app_spacing.dart';
import '../../widgets/app_background.dart';

/// Splash animata mostrata da AuthGate all'avvio: l'onda del logo si traccia
/// come una pennellata (il painter mappa da solo le fasi onda/eco sul
/// progress), poi il titolo sfuma in vista salendo. A fine corsa chiama
/// [onFinished] — una sola volta, in un post-frame callback.
///
/// Accessibilità: con "riduci animazioni" attivo (MediaQuery.disableAnimations)
/// salta la pennellata: logo statico e [onFinished] immediata.
class AnimatedSplashScreen extends StatefulWidget {
  /// Invocata quando l'animazione è conclusa (o subito, se disattivata).
  final VoidCallback onFinished;

  /// Mostra lo spinner sotto il titolo: serve quando l'animazione è finita
  /// ma lo stato di autenticazione non è ancora noto.
  final bool showSpinner;

  const AnimatedSplashScreen({
    super.key,
    required this.onFinished,
    this.showSpinner = false,
  });

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 1500);

  late final AnimationController _controller;

  /// Comparsa del titolo: ultimo tratto della timeline (0,9–1,4 s circa).
  late final Animation<double> _title;

  bool _finishedNotified = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    _title = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 0.94, curve: Curves.easeOut),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _notifyFinished();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery si può leggere solo da qui in poi (non in initState);
    // il flag evita di far ripartire l'animazione a ogni rebuild ereditato.
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      // Saltare al fondo fa scattare lo status listener → onFinished.
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
  }

  void _notifyFinished() {
    if (_finishedNotified) return;
    _finishedNotified = true;
    // Post-frame: il chiamante (AuthGate) fa setState, che non è permesso
    // mentre questo frame è ancora in corso.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShiftFlowLogo(size: 120, progress: _controller.value),
                  const SizedBox(height: AppSpacing.lg),
                  Opacity(
                    opacity: _title.value,
                    child: Transform.translate(
                      // Piccola salita (12px) mentre sfuma in vista.
                      offset: Offset(0, (1 - _title.value) * 12),
                      child: Text(
                        'ShiftFlow',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // Il posto dello spinner è sempre riservato: quando compare
                  // non sposta il resto del layout.
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: widget.showSpinner
                        ? const CircularProgressIndicator(strokeWidth: 2.5)
                        : null,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Verificare che i test passino**

Run: `flutter analyze && flutter test`
Expected: analyze pulito, tutti PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/shared/animated_splash_screen.dart test/screens/animated_splash_screen_test.dart
git commit -m "feat: schermata splash animata (onda che si disegna)"
```

---

### Task 3: `AuthGate` tiene la splash finché intro e stato non sono pronti

**Files:**
- Modify: `lib/screens/shared/auth_gate.dart` (riscrittura completa del widget)

**Interfaces:**
- Consumes: `AnimatedSplashScreen({onFinished, showSpinner})` dal Task 2;
  `AuthProvider.status` / `.isDeactivated` esistenti.
- Produces: nessuna API nuova (AuthGate resta il widget montato in `main.dart`).

- [ ] **Step 1: Riscrivere AuthGate**

Sostituire l'intero contenuto di `lib/screens/shared/auth_gate.dart` con:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import 'animated_splash_screen.dart';
import 'disabled_account_screen.dart';
import 'role_home.dart';

/// "Cancello" d'ingresso dell'app: guarda lo stato di [AuthProvider] e decide
/// quale schermata mostrare. È il punto in cui login e home si scambiano
/// automaticamente, senza navigazione manuale: quando lo stato cambia, questo
/// widget si ridisegna e mostra l'altra schermata.
///
/// È stateful per un solo motivo: la splash animata d'avvio va vista per
/// intero UNA volta ([_introDone]), anche se Firebase risponde prima che
/// l'animazione finisca.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// True quando l'animazione d'ingresso è stata vista per intero. Non torna
  /// mai false: dopo un logout si va dritti al login, senza ripetere la splash.
  bool _introDone = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final status = auth.status;

    // Splash finché l'intro non è conclusa E lo stato non è noto. Se
    // l'animazione è finita ma Firebase non ha ancora risposto, compare lo
    // spinner sotto il titolo.
    if (!_introDone || status == AuthStatus.unknown) {
      return AnimatedSplashScreen(
        showSpinner: _introDone,
        onFinished: () => setState(() => _introDone = true),
      );
    }

    if (status == AuthStatus.unauthenticated) {
      return const LoginScreen();
    }

    // Autenticato ma disattivato/rimosso nell'anagrafica: accesso negato (UC2-E2).
    return auth.isDeactivated
        ? const DisabledAccountScreen()
        : const RoleHome();
  }
}
```

Nota: spariscono gli import ora inutili (`shiftflow_logo.dart`,
`app_spacing.dart`, `app_background.dart`) — la vecchia splash statica
inline è sostituita dal widget del Task 2.

- [ ] **Step 2: Verifica statica e test**

Run: `flutter analyze && flutter test`
Expected: analyze pulito (nessun import inutilizzato), tutti i test PASS.

- [ ] **Step 3: Verifica manuale sull'app**

Run: `flutter run` (su simulatore o dispositivo).
Verificare:
1. all'avvio l'onda si disegna, poi compaiono eco e titolo (~1,5 s), poi si
   entra in login o home;
2. avvio con sessione già attiva: l'animazione si vede comunque per intero;
3. (facoltativo) attivando "riduci animazioni" nelle impostazioni di sistema,
   la splash è statica e l'ingresso immediato.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/shared/auth_gate.dart
git commit -m "feat: AuthGate mostra la splash animata all'avvio"
```
