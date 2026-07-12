import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiftflow/core/constants/app_constants.dart';
import 'package:shiftflow/core/theme/app_theme.dart';
import 'package:shiftflow/widgets/request_status_chip.dart';

void main() {
  // Costruisce il chip dentro un tema reale (che porta i colori di stato).
  Widget wrap(String status) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: RequestStatusChip(status: status)),
  );

  testWidgets('mostra l\'etichetta giusta per ogni stato', (tester) async {
    await tester.pumpWidget(wrap(LeaveStatus.inAttesa));
    expect(find.text('In attesa'), findsOneWidget);

    await tester.pumpWidget(wrap(LeaveStatus.approvata));
    expect(find.text('Approvata'), findsOneWidget);

    await tester.pumpWidget(wrap(LeaveStatus.rifiutata));
    expect(find.text('Rifiutata'), findsOneWidget);

    await tester.pumpWidget(wrap(LeaveStatus.annullata));
    expect(find.text('Annullata'), findsOneWidget);
  });

  testWidgets('espone lo stato agli screen reader (Semantics)', (tester) async {
    await tester.pumpWidget(wrap(LeaveStatus.approvata));
    expect(find.bySemanticsLabel('Stato richiesta: Approvata'), findsOneWidget);
  });
}
