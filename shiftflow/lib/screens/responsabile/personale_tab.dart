import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_status_colors.dart';
import '../../core/utils/dialogs.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/initials_avatar.dart';
import 'add_dipendente_screen.dart';

/// Sezione "Personale" del Responsabile: anagrafica del locale in tempo
/// reale, con aggiunta (FAB) e rimozione (cestino con conferma) dei
/// dipendenti. Il titolare è mostrato ma non rimovibile.
class PersonaleTab extends StatefulWidget {
  const PersonaleTab({super.key});

  @override
  State<PersonaleTab> createState() => _PersonaleTabState();
}

class _PersonaleTabState extends State<PersonaleTab> {
  @override
  void initState() {
    super.initState();
    // A fine frame: il provider fa notifyListeners() subito, e farlo durante
    // la costruzione del widget non è permesso.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) {
        context.read<StaffProvider>().listenForRestaurant(user.restaurantId);
      }
    });
  }

  Future<void> _confirmRemove(AppUser member) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Rimuovere ${member.name}?',
      message:
          'Il dipendente non farà più parte del locale. '
          'I suoi turni passati resteranno nello storico.',
      confirmLabel: 'Rimuovi',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final provider = context.read<StaffProvider>();
    final ok = await provider.removeDipendente(member.uid);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Rimozione non riuscita.'),
        ),
      );
    }
  }

  Future<void> _setActive(AppUser member, {required bool active}) async {
    final provider = context.read<StaffProvider>();
    final ok = await provider.setActive(member.uid, active: active);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (active
                    ? '${member.name} riattivato.'
                    : '${member.name} disattivato.')
              : (provider.errorMessage ?? 'Operazione non riuscita.'),
        ),
      ),
    );
  }

  /// Menù azioni su un dipendente: disattiva/riattiva e rimuovi.
  Widget _memberMenu(AppUser member) {
    return PopupMenuButton<String>(
      tooltip: 'Azioni',
      onSelected: (value) {
        if (value == 'toggle') {
          _setActive(member, active: member.isDisattivato);
        } else if (value == 'remove') {
          _confirmRemove(member);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'toggle',
          child: Text(member.isDisattivato ? 'Riattiva' : 'Disattiva'),
        ),
        PopupMenuItem(
          value: 'remove',
          child: Text(
            'Rimuovi dal locale',
            // Rosso semantico: segnala che è un'azione distruttiva.
            style: TextStyle(color: Theme.of(context).statusColors.danger),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final staffProvider = context.watch<StaffProvider>();
    final currentUid = context.watch<AuthProvider>().currentUser?.uid;

    // Le barre della home sono trasparenti: la lista parte sotto la AppBar
    // e finisce oltre la NavigationBar.
    final insets = MediaQuery.paddingOf(context);
    final staff = staffProvider.staff;

    final Widget body = AsyncStateView(
      isLoading: staffProvider.isLoading,
      errorMessage: staffProvider.errorMessage,
      isEmpty: staff.isEmpty,
      emptyIcon: Icons.groups_rounded,
      emptyTitle: 'Nessun membro',
      emptySubtitle: 'Aggiungi il personale con il pulsante + qui sotto.',
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.sm,
          insets.top + AppSpacing.sm,
          AppSpacing.sm,
          AppSizes.fabClearance + insets.bottom,
        ),
        itemCount: staff.length,
        itemBuilder: (context, i) {
          final member = staff[i];
          // Il titolare (e l'utente stesso) non si possono rimuovere da qui.
          final manageable = !member.isResponsabile && member.uid != currentUid;
          final subtitle = member.isDisattivato
              ? '${member.email} · Disattivato'
              : member.email;
          return GlassCard(
            child: ListTile(
              leading: InitialsAvatar(name: member.name),
              title: Text(member.name),
              subtitle: Text(subtitle),
              trailing: manageable
                  ? _memberMenu(member)
                  : Chip(
                      label: Text(member.isResponsabile ? 'Titolare' : 'Tu'),
                      visualDensity: VisualDensity.compact,
                    ),
            ),
          );
        },
      ),
    );

    // Scaffold annidato trasparente: ancora il FAB a questa sezione e lascia
    // vedere lo sfondo ambientale della home.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: body,
      // Il Padding alza il FAB sopra la NavigationBar trasparente della home
      // (lo Scaffold interno non sa quanto è alta: glielo diciamo noi).
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: insets.bottom),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddDipendenteScreen()),
            );
          },
          icon: const Icon(Icons.person_add_rounded),
          label: const Text('Aggiungi'),
        ),
      ),
    );
  }
}
