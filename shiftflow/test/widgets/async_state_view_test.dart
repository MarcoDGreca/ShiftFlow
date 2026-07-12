import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiftflow/widgets/async_state_view.dart';
import 'package:shiftflow/widgets/placeholder_view.dart';

void main() {
  Widget wrap({
    required bool isLoading,
    String? errorMessage,
    required bool isEmpty,
  }) => MaterialApp(
    home: Scaffold(
      body: AsyncStateView(
        isLoading: isLoading,
        errorMessage: errorMessage,
        isEmpty: isEmpty,
        emptyIcon: Icons.inbox_rounded,
        emptyTitle: 'Vuoto',
        emptySubtitle: 'Niente qui',
        child: const Text('CONTENUTO'),
      ),
    ),
  );

  testWidgets('caricamento: mostra lo spinner', (tester) async {
    await tester.pumpWidget(
      wrap(isLoading: true, errorMessage: null, isEmpty: true),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('CONTENUTO'), findsNothing);
  });

  testWidgets('errore con lista vuota: mostra il placeholder d\'errore', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(isLoading: false, errorMessage: 'Boom', isEmpty: true),
    );
    expect(find.byType(PlaceholderView), findsOneWidget);
    expect(find.text('Boom'), findsOneWidget);
  });

  testWidgets('vuoto senza errore: mostra il placeholder vuoto', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(isLoading: false, errorMessage: null, isEmpty: true),
    );
    expect(find.text('Vuoto'), findsOneWidget);
    expect(find.text('CONTENUTO'), findsNothing);
  });

  testWidgets('con dati: mostra il contenuto', (tester) async {
    await tester.pumpWidget(
      wrap(isLoading: false, errorMessage: null, isEmpty: false),
    );
    expect(find.text('CONTENUTO'), findsOneWidget);
    expect(find.byType(PlaceholderView), findsNothing);
  });

  testWidgets('errore ma con dati già presenti: mostra comunque i dati', (
    tester,
  ) async {
    // Dati vecchi sono più utili di un errore a tutto schermo.
    await tester.pumpWidget(
      wrap(isLoading: false, errorMessage: 'Boom', isEmpty: false),
    );
    expect(find.text('CONTENUTO'), findsOneWidget);
  });
}
