import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import 'home_placeholder.dart';

/// "Cancello" d'ingresso dell'app: guarda lo stato di [AuthProvider] e decide
/// quale schermata mostrare. È il punto in cui login e home si scambiano
/// automaticamente, senza navigazione manuale: quando lo stato cambia, questo
/// widget si ridisegna e mostra l'altra schermata.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthProvider>().status;

    switch (status) {
      case AuthStatus.unknown:
        // All'avvio, mentre Firebase ci dice se c'è già una sessione.
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.authenticated:
        return const HomePlaceholder();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}
