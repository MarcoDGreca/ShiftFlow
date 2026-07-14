import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiftflow/core/branding/shiftflow_logo.dart';

void main() {
  testWidgets('renderizza senza errori a vari progress', (tester) async {
    for (final p in [0.0, 0.3, 0.65, 1.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: ShiftFlowLogo(size: 64, progress: p)),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'progress $p');
    }
  });

  testWidgets('renderizza senza errori anche in versione monochrome',
      (tester) async {
    for (final p in [0.0, 0.5, 1.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: ShiftFlowLogo(size: 64, monochrome: true, progress: p),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'progress $p');
    }
  });

  test('shouldRepaint scatta quando cambia progress', () {
    const prima = ShiftFlowLogoPainter(progress: 0.3);
    const dopo = ShiftFlowLogoPainter(progress: 0.6);
    expect(dopo.shouldRepaint(prima), isTrue);
  });

  test('shouldRepaint NON scatta a parità di parametri', () {
    const prima = ShiftFlowLogoPainter();
    const dopo = ShiftFlowLogoPainter();
    expect(dopo.shouldRepaint(prima), isFalse);
  });
}
