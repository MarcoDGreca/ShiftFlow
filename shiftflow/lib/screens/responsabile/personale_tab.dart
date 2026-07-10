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
          final removable =
              !member.isResponsabile && member.uid != currentUid;
          return Card(
            child: ListTile(
              leading: InitialsAvatar(name: member.name),
              title: Text(member.name),
              subtitle: Text(member.email),
              trailing: removable
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Rimuovi dal locale',
                      onPressed: () => _confirmRemove(member),
                    )
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
