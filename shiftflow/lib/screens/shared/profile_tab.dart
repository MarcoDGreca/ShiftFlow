import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/auth_provider.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/initials_avatar.dart';

/// Sezione "Profilo", condivisa tra Dipendente e Responsabile.
/// Mostra i dati dell'utente loggato (letti da `users/{uid}`) e il logout.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  @override
  void initState() {
    super.initState();
    // Carica il nome del locale da mostrare al posto dell'ID grezzo.
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      context.read<StaffProvider>().loadRestaurant(user.restaurantId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final restaurant = context.watch<StaffProvider>().restaurant;
    final theme = Theme.of(context);

    // Etichetta leggibile del ruolo.
    final isResponsabile = user?.role == UserRoles.responsabile;
    final roleLabel = isResponsabile ? 'Responsabile' : 'Dipendente';

    // Le barre della home sono trasparenti: la lista parte sotto la AppBar
    // e finisce oltre la NavigationBar (ci scorre sotto, effetto vetro).
    final insets = MediaQuery.paddingOf(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        insets.top + AppSpacing.lg,
        AppSpacing.lg,
        insets.bottom + AppSpacing.lg,
      ),
      children: [
        Center(child: InitialsAvatar(name: user?.name, radius: 48)),
        const SizedBox(height: AppSpacing.md),
        Text(
          user?.name ?? '',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Chip(
            avatar: Icon(
              isResponsabile
                  ? Icons.workspace_premium_rounded
                  : Icons.badge_rounded,
              size: 18,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            label: Text(roleLabel),
            labelStyle: TextStyle(color: theme.colorScheme.onPrimaryContainer),
            backgroundColor: theme.colorScheme.primaryContainer,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        GlassCard(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                subtitle: Text(user?.email ?? '-'),
              ),
              if (restaurant != null) ...[
                Divider(
                  height: 1,
                  indent: AppSpacing.md,
                  endIndent: AppSpacing.md,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: const Text('Locale'),
                  subtitle: Text(
                    restaurant.address.isEmpty
                        ? restaurant.name
                        : '${restaurant.name}\n${restaurant.address}',
                  ),
                  isThreeLine: restaurant.address.isNotEmpty,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: () => context.read<AuthProvider>().signOut(),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Esci'),
        ),
      ],
    );
  }
}
