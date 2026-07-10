import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/initials_avatar.dart';

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
        Center(child: InitialsAvatar(name: user?.name, radius: 40)),
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

}
