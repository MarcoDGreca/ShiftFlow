import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_status_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/section_header.dart';
import 'edit_profile_screen.dart';

/// Sezione "Profilo", condivisa tra Dipendente e Responsabile.
/// Mostra i dati dell'utente loggato (letti da `users/{uid}`) e il logout.
///
/// I dati sono raggruppati per argomento (Contatti / Dettagli / Locale):
/// blocchi piccoli con un titolo si scandiscono meglio di un'unica card
/// lunga (regola del raggruppamento). Il logout usa il colore "pericolo":
/// non è distruttivo ma interrompe la sessione, meglio distinguerlo bene.
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

  /// Padding degli header di sezione, allineato alle card sottostanti.
  static const _headerPadding = EdgeInsets.fromLTRB(
    AppSpacing.xs,
    AppSpacing.lg,
    AppSpacing.xs,
    AppSpacing.sm,
  );

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final restaurant = context.watch<StaffProvider>().restaurant;
    final theme = Theme.of(context);
    final statusColors = theme.statusColors;

    final phone = user?.phone ?? '';
    final position = user?.position ?? '';
    final birthDate = user?.birthDate;

    // Etichetta leggibile del ruolo.
    final isResponsabile = user?.role == UserRoles.responsabile;
    final roleLabel = isResponsabile ? 'Responsabile' : 'Dipendente';

    // Le barre della home sono trasparenti: la lista parte sotto la AppBar
    // e finisce oltre la NavigationBar (ci scorre sotto, effetto vetro).
    final insets = MediaQuery.paddingOf(context);

    // Vincolata in larghezza come le altre schermate: su tablet il contenuto
    // non si allarga a nastro ma resta centrato in una colonna leggibile.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ListView(
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
                labelStyle: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                backgroundColor: theme.colorScheme.primaryContainer,
              ),
            ),

            const SectionHeader(
              title: 'Contatti',
              padding: _headerPadding,
            ),
            GlassCard(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _infoTile(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    value: user?.email ?? '-',
                  ),
                  _divider(theme),
                  _infoTile(
                    icon: Icons.phone_outlined,
                    title: 'Telefono',
                    value: phone.isEmpty ? 'Non impostato' : phone,
                    placeholder: phone.isEmpty,
                  ),
                ],
              ),
            ),

            const SectionHeader(
              title: 'Dettagli',
              padding: _headerPadding,
            ),
            GlassCard(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _infoTile(
                    icon: Icons.work_outline_rounded,
                    title: 'Mansione',
                    value: position.isEmpty ? 'Non impostata' : position,
                    placeholder: position.isEmpty,
                  ),
                  _divider(theme),
                  _infoTile(
                    icon: Icons.cake_outlined,
                    title: 'Data di nascita',
                    value: birthDate != null
                        ? DateFormatter.dayMonthYearFull(birthDate)
                        : 'Non impostata',
                    placeholder: birthDate == null,
                  ),
                ],
              ),
            ),

            if (restaurant != null) ...[
              const SectionHeader(
                title: 'Locale',
                padding: _headerPadding,
              ),
              GlassCard(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(restaurant.name),
                  subtitle: restaurant.address.isEmpty
                      ? null
                      : Text(restaurant.address),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              ),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Modifica profilo'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: statusColors.danger,
                side: BorderSide(
                  color: statusColors.danger.withValues(alpha: 0.45),
                ),
              ),
              onPressed: () => context.read<AuthProvider>().signOut(),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Esci'),
            ),
          ],
        ),
      ),
    );
  }

  /// Riga informativa della card profilo. Con [placeholder] a `true` il valore
  /// è un segnaposto ("Non impostato"): lo mostriamo attenuato e in corsivo.
  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
    bool placeholder = false,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        value,
        style: placeholder
            ? theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              )
            : null,
      ),
    );
  }

  /// Sottile separatore tra le righe della card, rientrato ai lati.
  Widget _divider(ThemeData theme) => Divider(
    height: 1,
    indent: AppSpacing.md,
    endIndent: AppSpacing.md,
    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
  );
}
