import 'package:flutter_test/flutter_test.dart';
import 'package:shiftflow/models/shift.dart';

/// Turno minimo per i test: contano solo giorno e orario d'inizio.
Shift _shift({required DateTime date, required String startTime}) => Shift(
  id: 's1',
  employeeUid: 'emp',
  date: date,
  startTime: startTime,
  endTime: '23:00',
  createdBy: 'mgr',
);

void main() {
  // Riferimento fisso: mezzogiorno del 14 luglio 2026.
  final moment = DateTime(2026, 7, 14, 12, 0);

  group('Shift.startsAfter', () {
    test('turno di domani: inizia dopo', () {
      final shift = _shift(date: DateTime(2026, 7, 15), startTime: '09:00');
      expect(shift.startsAfter(moment), isTrue);
    });

    test('turno di ieri: già iniziato', () {
      final shift = _shift(date: DateTime(2026, 7, 13), startTime: '18:00');
      expect(shift.startsAfter(moment), isFalse);
    });

    test('turno di oggi più tardi: inizia dopo', () {
      final shift = _shift(date: DateTime(2026, 7, 14), startTime: '18:00');
      expect(shift.startsAfter(moment), isTrue);
    });

    test('turno di oggi in corso: già iniziato', () {
      final shift = _shift(date: DateTime(2026, 7, 14), startTime: '08:00');
      expect(shift.startsAfter(moment), isFalse);
    });

    test('inizio esattamente adesso: conta come iniziato', () {
      final shift = _shift(date: DateTime(2026, 7, 14), startTime: '12:00');
      expect(shift.startsAfter(moment), isFalse);
    });

    test('orario malformato: conta come iniziato (nel dubbio si conserva)', () {
      final shift = _shift(date: DateTime(2026, 7, 15), startTime: 'boh');
      expect(shift.startsAfter(moment), isFalse);
    });

    test('orario vuoto: conta come iniziato (nel dubbio si conserva)', () {
      final shift = _shift(date: DateTime(2026, 7, 15), startTime: '');
      expect(shift.startsAfter(moment), isFalse);
    });
  });
}
