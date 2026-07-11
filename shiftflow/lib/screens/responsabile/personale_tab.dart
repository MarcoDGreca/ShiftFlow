import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/placeholder_view.dart';
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
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      context.read<StaffProvider>().listenForRestaurant(user.restaurantId);
    }
  }

  Future<void> _confirmRemove(AppUser member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Rimuovere ${member.name}?'),
        content: const Text(
          'Il dipendente non farà più parte del locale. '
          'I suoi turni passati resteranno nello storico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

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
        content: Text(ok
            ? (active
                ? '${member.name} riattivato.'
                : '${member.name} disattivato.')
            : (provider.errorMessage ?? 'Operazione non riuscita.')),
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
        const PopupMenuItem(
          value: 'remove',
          child: Text('Rimuovi dal locale'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final staffProvider = context.watch<StaffProvider>();
    final currentUid = context.watch<AuthProvider>().currentUser?.uid;

    final Widget body;
    if (staffProvider.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (staffProvider.errorMessage != null &&
        staffProvider.staff.isEmpty) {
      body = PlaceholderView(
        icon: Icons.error_outline,
        title: 'Qualcosa è andato storto',
        subtitle: staffProvider.errorMessage!,
      );
    } else {
      final staff = staffProvider.staff;
      body = ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 88), // spazio per il FAB
        itemCount: staff.length,
        itemBuilder: (context, i) {
          final member = staff[i];
          // Il titolare (e l'utente stesso) non si possono rimuovere da qui.
          final manageable =
              !member.isResponsabile && member.uid != currentUid;
          final subtitle = member.isDisattivato
              ? '${member.email} · Disattivato'
              : member.email;
          return Card(
            child: ListTile(
              leading: InitialsAvatar(name: member.name),
              title: Text(member.name),
              subtitle: Text(subtitle),
              trailing: manageable
                  ? _memberMenu(member)
                  : Chip(
                      label: Text(
                        member.isResponsabile ? 'Titolare' : 'Tu',
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
            ),
          );
        },
      );
    }

    return Scaffold(
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddDipendenteScreen()),
          );
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Aggiungi'),
      ),
    );
  }
}
