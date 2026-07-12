import 'package:flutter_test/flutter_test.dart';
import 'package:shiftflow/core/utils/date_formatter.dart';
import 'package:shiftflow/services/shift_service.dart';

void main() {
  group('DateFormatter.timeRange / isOvernight', () {
    test('turno diurno: nessun suffisso', () {
      expect(DateFormatter.isOvernight('09:00', '17:00'), isFalse);
      expect(DateFormatter.timeRange('09:00', '17:00'), '09:00–17:00');
    });

    test('turno notturno: suffisso (+1)', () {
      expect(DateFormatter.isOvernight('22:00', '02:00'), isTrue);
      expect(DateFormatter.timeRange('22:00', '02:00'), '22:00–02:00 (+1)');
    });

    test('orari uguali non sono notturni', () {
      expect(DateFormatter.isOvernight('10:00', '10:00'), isFalse);
    });
  });

  group('ShiftService.timesOverlap', () {
    test('due turni diurni che si accavallano', () {
      expect(
        ShiftService.timesOverlap('09:00', '13:00', '12:00', '17:00'),
        isTrue,
      );
    });

    test('due turni diurni consecutivi non si sovrappongono', () {
      // Il primo finisce alle 13:00, il secondo inizia alle 13:00.
      expect(
        ShiftService.timesOverlap('09:00', '13:00', '13:00', '17:00'),
        isFalse,
      );
    });

    test('turno notturno che si sovrappone a un altro serale', () {
      // 22:00–02:00 (finisce il giorno dopo) e 23:00–01:00 dello stesso
      // giorno condividono la fascia 23:00–01:00.
      expect(
        ShiftService.timesOverlap('22:00', '02:00', '23:00', '01:00'),
        isTrue,
      );
    });

    test('turno notturno e turno serale separato non si sovrappongono', () {
      // Stesso giorno: 22:00–02:00 (sera→notte) vs 01:00–05:00 (mattina
      // presto dello stesso giorno) NON si toccano. NB: una sovrapposizione
      // col turno del giorno SUCCESSIVO non è rilevata (limite documentato).
      expect(
        ShiftService.timesOverlap('22:00', '02:00', '01:00', '05:00'),
        isFalse,
      );
    });
  });
}
