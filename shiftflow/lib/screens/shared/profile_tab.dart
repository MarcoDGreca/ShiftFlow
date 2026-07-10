import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';

/// Sezione "Profilo", condivisa tra Dipendente e Responsabile.
/// Mostra i dati dell'utente loggato (letti da `users/{uid}`) e il logout.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final theme = Theme.of(context);

    // Etichetta leggibile del ruolo.
    final roleLabel = user?.role == UserRoles.responsabile
        ? 'Responsabile'
        : 'Dipendente';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        CircleAvatar(
          radius: 40,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            _initials(user?.name),
            style: theme.textTheme.headlineMedium
                ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user?.name ?? '',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 24),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Ruolo'),
                subtitle: Text(roleLabel),
              ),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                subtitle: Text(user?.email ?? '-'),
              ),
              ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('Locale (ID)'),
                subtitle: Text(user?.restaurantId ?? '-'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => context.read<AuthProvider>().signOut(),
          icon: const Icon(Icons.logout),
          label: const Text('Esci'),
        ),
      ],
    );
  }

  /// Ricava le iniziali dal nome per l'avatar (es. "Marco Rossi" -> "MR").
  String _initials(String? name) {
    final parts =
        (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}
