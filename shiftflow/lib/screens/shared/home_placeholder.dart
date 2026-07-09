import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

/// Home temporanea mostrata dopo il login, utile solo per verificare che
/// l'accesso funzioni: mostra i dati del profilo letti da `users/{uid}` e un
/// pulsante di logout. La vera home (diversa per Dipendente e Responsabile)
/// arriverà nei prossimi passi.
class HomePlaceholder extends StatelessWidget {
  const HomePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ShiftFlow'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Esci',
            onPressed: () => context.read<AuthProvider>().signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 64),
            const SizedBox(height: 16),
            Text(
              'Benvenuto, ${user?.name ?? ''}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Ruolo: ${user?.role ?? '-'}'),
            Text('Locale: ${user?.restaurantId ?? '-'}'),
          ],
        ),
      ),
    );
  }
}
