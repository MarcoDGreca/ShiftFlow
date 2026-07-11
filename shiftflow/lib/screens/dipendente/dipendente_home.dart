import 'package:flutter/material.dart';

import '../shared/profile_tab.dart';
import 'richieste_tab.dart';
import 'turni_tab.dart';

/// Home del Dipendente: un guscio con la barra di navigazione in basso e tre
/// sezioni (I miei turni, Le mie richieste, Profilo).
///
/// È uno `StatefulWidget` perché deve ricordare quale scheda è selezionata.
class DipendenteHome extends StatefulWidget {
  const DipendenteHome({super.key});

  @override
  State<DipendenteHome> createState() => _DipendenteHomeState();
}

class _DipendenteHomeState extends State<DipendenteHome> {
  int _index = 0;

  static const _titles = ['I miei turni', 'Le mie richieste', 'Profilo'];

  // IndexedStack tiene "vive" tutte le schede e mostra solo quella scelta,
  // così cambiando tab non si perde il loro stato.
  static const _pages = [
    TurniTab(),
    RichiesteTab(),
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
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'Turni',
          ),
          NavigationDestination(
            icon: Icon(Icons.mail_outline),
            selectedIcon: Icon(Icons.mail),
            label: 'Richieste',
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
