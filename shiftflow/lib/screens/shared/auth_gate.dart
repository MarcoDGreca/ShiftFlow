import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/branding/shiftflow_logo.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_background.dart';
import '../auth/login_screen.dart';
import 'role_home.dart';

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
        // All'avvio, mentre Firebase ci dice se c'è già una sessione:
        // splash brandizzato che prosegue quello nativo.
        return Scaffold(
          body: AppBackground(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ShiftFlowLogo(size: 120),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'ShiftFlow',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ],
              ),
            ),
          ),
        );
      case AuthStatus.authenticated:
        return const RoleHome();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}
