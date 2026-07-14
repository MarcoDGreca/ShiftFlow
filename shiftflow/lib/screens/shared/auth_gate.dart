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
