import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/leave_request_provider.dart';
import '../../widgets/app_background.dart';
import '../../widgets/glass_container.dart';
import '../shared/profile_tab.dart';
import 'calendario_tab.dart';
import 'personale_tab.dart';
import 'richieste_tab.dart';

/// Home del Responsabile: guscio con barra di navigazione a quattro sezioni
/// (Calendario, Richieste, Personale, Profilo), tutte funzionanti.
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
    RichiesteResponsabileTab(),
    PersonaleTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    // Numero di richieste in attesa: alimenta il badge sulla scheda Richieste.
    final pending = context.watch<LeaveRequestProvider>().pendingCount;

    return Scaffold(
      // Il contenuto si estende dietro le barre trasparenti: così le liste
      // scorrono "sotto il vetro" di AppBar e NavigationBar.
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_titles[_index]),
        flexibleSpace: const GlassBarBackground(),
      ),
      body: AppBackground(
        child: IndexedStack(index: _index, children: _pages),
      ),
      bottomNavigationBar: GlassContainer(
        blur: true,
        borderRadius: BorderRadius.zero,
        showBorder: false,
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Calendario',
            ),
            NavigationDestination(
              // Badge.count mostra il pallino col numero solo se ci sono pendenti.
              icon: Badge.count(
                count: pending,
                isLabelVisible: pending > 0,
                child: const Icon(Icons.inbox_outlined),
              ),
              selectedIcon: Badge.count(
                count: pending,
                isLabelVisible: pending > 0,
                child: const Icon(Icons.inbox),
              ),
              label: 'Richieste',
            ),
            const NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: 'Personale',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profilo',
            ),
          ],
        ),
      ),
    );
  }
}
