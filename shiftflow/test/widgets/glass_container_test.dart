import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiftflow/widgets/glass_container.dart';

void main() {
  Widget wrap({required bool highContrast, required bool blur}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(highContrast: highContrast),
      child: Scaffold(
        body: GlassContainer(blur: blur, child: const Text('DENTRO')),
      ),
    ),
  );

  testWidgets('mostra sempre il figlio', (tester) async {
    await tester.pumpWidget(wrap(highContrast: false, blur: true));
    expect(find.text('DENTRO'), findsOneWidget);
  });

  testWidgets('con blur normale usa un BackdropFilter di sfocatura', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(highContrast: false, blur: true));
    final blurs = tester
        .widgetList<BackdropFilter>(find.byType(BackdropFilter))
        .where((b) => b.filter is ImageFilter);
    expect(blurs, isNotEmpty);
  });

  testWidgets('con alto contrasto il vetro diventa opaco (niente blur)', (
    tester,
  ) async {
    // Fallback di accessibilità: nessuna sfocatura costosa/illeggibile.
    await tester.pumpWidget(wrap(highContrast: true, blur: true));
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('DENTRO'), findsOneWidget);
  });
}
