import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiftflow/core/theme/app_theme.dart';
import 'package:shiftflow/core/utils/dialogs.dart';

void main() {
  // Pompa un bottone che apre il dialogo e registra il valore restituito.
  Future<bool?> openAndTap(WidgetTester tester, String buttonText) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showAppConfirmDialog(
                  context,
                  title: 'Sicuro?',
                  message: 'Azione da confermare',
                  confirmLabel: 'Conferma',
                  destructive: true,
                );
              },
              child: const Text('APRI'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('APRI'));
    await tester.pumpAndSettle();
    expect(find.text('Sicuro?'), findsOneWidget); // il dialogo è aperto

    await tester.tap(find.text(buttonText));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('ritorna true quando si conferma', (tester) async {
    final result = await openAndTap(tester, 'Conferma');
    expect(result, isTrue);
  });

  testWidgets('ritorna false quando si annulla', (tester) async {
    final result = await openAndTap(tester, 'Annulla');
    expect(result, isFalse);
  });
}
