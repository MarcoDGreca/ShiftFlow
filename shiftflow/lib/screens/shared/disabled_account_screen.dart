import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_background.dart';
import '../../widgets/glass_container.dart';

/// Mostrata quando un utente autenticato risulta DISATTIVATO nell'anagrafica
/// del locale (UC2-E2): l'accesso alle funzioni è negato e si invita a
/// contattare il responsabile. L'unica azione disponibile è uscire.
class DisabledAccountScreen extends StatelessWidget {
  const DisabledAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: GlassContainer(
                blur: true,
                borderRadius: const BorderRadius.all(Radius.circular(AppRadius.xl)),
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Account disattivato',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Il tuo accesso è stato sospeso dal responsabile del locale. '
                      'Per riattivarlo, contattalo direttamente.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: () => context.read<AuthProvider>().signOut(),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Esci'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
