import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../dipendente/dipendente_home.dart';
import '../responsabile/responsabile_home.dart';

/// Smista l'utente autenticato verso la home giusta in base al ruolo letto da
/// `users/{uid}`. Viene mostrato dall'`AuthGate` quando lo stato è
/// "authenticated".
class RoleHome extends StatelessWidget {
  const RoleHome({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    // Difensivo: in teoria qui l'utente c'è sempre (siamo "authenticated").
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return user.isResponsabile
        ? const ResponsabileHome()
        : const DipendenteHome();
  }
}
