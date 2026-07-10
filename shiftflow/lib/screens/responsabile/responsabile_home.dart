import 'package:flutter/material.dart';

import '../../widgets/placeholder_view.dart';
import '../shared/profile_tab.dart';
import 'calendario_tab.dart';

/// Home del Responsabile: guscio con barra di navigazione a quattro sezioni.
/// Calendario, Richieste e Personale sono segnaposto per ora; Profilo è già
/// funzionante. Le sezioni verranno riempite nei prossimi passi.
class ResponsabileHome extends StatefulWidget {
  const ResponsabileHome({super.key});

  @override
  State<ResponsabileHome> createState() => _ResponsabileHomeState();
}

class _ResponsabileHomeState extends State<ResponsabileHome> {
  int _index = 0;

  static const _titles = ['Calendario', 'Richieste', 'Personale', 'Profilo'];

  static const _pages = [
    CalendarioTab(),
    PlaceholderView(
      icon: Icons.inbox_outlined,
      title: 'Richieste del personale',
      subtitle: 'Qui approverai o rifiuterai permessi e cambi turno.',
    ),
    PlaceholderView(
      icon: Icons.groups_outlined,
      title: 'Personale del locale',
      subtitle: 'Qui gestirai l\'anagrafica dei dipendenti.',
    ),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendario',
          ),
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: 'Richieste',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Personale',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profilo',
          ),
        ],
      ),
    );
  }
}
