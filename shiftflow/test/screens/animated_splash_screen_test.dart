import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiftflow/screens/shared/animated_splash_screen.dart';

void main() {
  testWidgets('chiama onFinished quando l\'animazione termina',
      (tester) async {
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedSplashScreen(onFinished: () => finished = true),
      ),
    );

    // A metà corsa non deve ancora aver chiamato il callback.
    await tester.pump(const Duration(milliseconds: 800));
    expect(finished, isFalse);

    // Oltre la durata totale (~1,5 s) + il post-frame callback.
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(finished, isTrue);
  });

  testWidgets('con "riduci animazioni" attivo finisce subito', (tester) async {
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: AnimatedSplashScreen(onFinished: () => finished = true),
        ),
      ),
    );
    await tester.pump(); // post-frame callback
    expect(finished, isTrue);
  });

  testWidgets('mostra lo spinner solo se richiesto', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedSplashScreen(onFinished: () {}, showSpinner: true),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(home: AnimatedSplashScreen(onFinished: () {})),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('mostra logo e titolo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AnimatedSplashScreen(onFinished: () {})),
    );
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('ShiftFlow'), findsOneWidget);
  });
}
