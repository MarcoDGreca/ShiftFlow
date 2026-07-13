import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_status_colors.dart';
import '../../core/utils/dialogs.dart';
import '../../models/app_user.dart';
import '../../models/leave_request.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_request_provider.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/info_pill.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/section_header.dart';
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
        // Le assenze approvate alimentano la pillola "In ferie/permesso"
        // accanto ai membri assenti oggi (sottoscrizione idempotente).
        context.read<LeaveRequestProvider>().listenForRestaurant(
          user.restaurantId,
        );
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

  /// Apre il form di aggiunta (dal FAB o dall'empty state).
  void _openAdd() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddDipendenteScreen()));
  }

  /// Riepilogo del team per l'intestazione, es. "4 attivi · 1 disattivato".
  String _teamSummary(List<AppUser> staff) {
    final active = staff.where((m) => m.isAttivo).length;
    final inactive = staff.length - active;
    final parts = [
      active == 1 ? '1 attivo' : '$active attivi',
      if (inactive > 0)
        inactive == 1 ? '1 disattivato' : '$inactive disattivati',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final staffProvider = context.watch<StaffProvider>();
    final leaveProvider = context.watch<LeaveRequestProvider>();
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
      emptySubtitle:
          'Crea gli account dei tuoi dipendenti: potranno vedere i turni '
          'e inviarti richieste.',
      emptyActionLabel: 'Aggiungi dipendente',
      emptyActionIcon: Icons.person_add_rounded,
      onEmptyAction: _openAdd,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.sm,
          insets.top + AppSpacing.sm,
          AppSpacing.sm,
          AppSizes.fabClearance + insets.bottom,
        ),
        // +1: la prima riga è l'intestazione con il riepilogo del team.
        itemCount: staff.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return SectionHeader(
              title: 'Team',
              trailing: _teamSummary(staff),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.xs,
              ),
            );
          }
          final member = staff[i - 1];
          // Il titolare (e l'utente stesso) non si possono rimuovere da qui.
          final manageable = !member.isResponsabile && member.uid != currentUid;
          return _MemberCard(
            member: member,
            // Assenza approvata che copre OGGI: alimenta la pillola
            // "In ferie/permesso" (stato derivato: scade da solo).
            todayLeave: leaveProvider.leaveFor(member.uid, DateTime.now()),
            trailing: manageable ? _memberMenu(member) : _roleChip(member),
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
          onPressed: _openAdd,
          icon: const Icon(Icons.person_add_rounded),
          label: const Text('Aggiungi'),
        ),
      ),
    );
  }

  /// Chip per i membri non gestibili da qui: il titolare e l'utente stesso.
  Widget _roleChip(AppUser member) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text(member.isResponsabile ? 'Titolare' : 'Tu'),
      labelStyle: TextStyle(color: scheme.onPrimaryContainer),
      backgroundColor: scheme.primaryContainer.withValues(alpha: 0.7),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Riga di un membro del personale. Lo stato si legge a colpo d'occhio, senza
/// cercarlo dentro al testo: avatar attenuato e pillola "Disattivato" per chi
/// è disattivato; pillola "In ferie"/"In permesso" per chi è assente oggi
/// ([todayLeave]) — tornerà normale da sola alla fine del periodo.
class _MemberCard extends StatelessWidget {
  final AppUser member;
  final LeaveRequest? todayLeave;
  final Widget trailing;

  const _MemberCard({
    required this.member,
    required this.trailing,
    this.todayLeave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColors = theme.statusColors;
    final disattivato = member.isDisattivato;

    return GlassCard(
      child: ListTile(
        leading: Opacity(
          opacity: disattivato ? 0.45 : 1,
          child: InitialsAvatar(name: member.name),
        ),
        title: Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              member.name,
              style: disattivato
                  ? TextStyle(color: theme.colorScheme.onSurfaceVariant)
                  : null,
            ),
            if (disattivato)
              InfoPill(
                icon: Icons.pause_circle_outline_rounded,
                label: 'Disattivato',
                background: statusColors.warningContainer,
                foreground: statusColors.onWarningContainer,
              )
            else if (todayLeave != null)
              // Stessi colori semantici del resto dell'app: ferie = info,
              // permesso = attenzione.
              InfoPill(
                icon: todayLeave!.isFerie
                    ? Icons.beach_access_rounded
                    : Icons.more_time_rounded,
                label: todayLeave!.isFerie ? 'In ferie' : 'In permesso',
                background: todayLeave!.isFerie
                    ? statusColors.infoContainer
                    : statusColors.warningContainer,
                foreground: todayLeave!.isFerie
                    ? statusColors.onInfoContainer
                    : statusColors.onWarningContainer,
              ),
          ],
        ),
        subtitle: Text(member.email),
        trailing: trailing,
      ),
    );
  }
}
