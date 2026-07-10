import 'package:flutter_test/flutter_test.dart';
import 'package:shiftflow/core/utils/date_formatter.dart';

void main() {
  group('DateFormatter', () {
    // Il 9 luglio 2026 è un giovedì.
    final date = DateTime(2026, 7, 9);

    test('toDayLabel', () {
      expect(DateFormatter.toDayLabel(date), '9/7/2026');
    });

    test('full: giorno della settimana e mese in italiano', () {
      expect(DateFormatter.full(date), 'gio 9 lug 2026');
    });

    test('full: lunedì e dicembre (estremi delle liste)', () {
      // Il 28 dicembre 2026 è un lunedì.
      expect(DateFormatter.full(DateTime(2026, 12, 28)), 'lun 28 dic 2026');
    });
  });
}
