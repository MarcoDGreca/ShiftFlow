/// Helper di formattazione di date e orari.
///
/// Nomi di giorni/mesi scritti a mano in italiano: l'app è monolingua e lo
/// stack concordato non prevede il package `intl`.
class DateFormatter {
  DateFormatter._();

  static const _weekdays = ['lun', 'mar', 'mer', 'gio', 'ven', 'sab', 'dom'];
  static const _months = [
    'gen',
    'feb',
    'mar',
    'apr',
    'mag',
    'giu',
    'lug',
    'ago',
    'set',
    'ott',
    'nov',
    'dic',
  ];

  static const _monthsFull = [
    'gennaio',
    'febbraio',
    'marzo',
    'aprile',
    'maggio',
    'giugno',
    'luglio',
    'agosto',
    'settembre',
    'ottobre',
    'novembre',
    'dicembre',
  ];

  /// Es. `9/7/2026`.
  static String toDayLabel(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';

  /// Es. `gio 9 lug 2026`. `DateTime.weekday` vale 1 (lunedì) … 7 (domenica).
  static String full(DateTime date) =>
      '${_weekdays[date.weekday - 1]} ${date.day} '
      '${_months[date.month - 1]} ${date.year}';

  /// Es. `luglio 2026` (intestazione del calendario mensile).
  static String monthYear(DateTime date) =>
      '${_monthsFull[date.month - 1]} ${date.year}';

  /// Es. `9 luglio 2005` (data per esteso senza giorno della settimana:
  /// adatta a una data di nascita).
  static String dayMonthYearFull(DateTime date) =>
      '${date.day} ${_monthsFull[date.month - 1]} ${date.year}';

  /// Es. `9 lug` (giorno + mese abbreviato, per intervalli compatti).
  static String dayMonthShort(DateTime date) =>
      '${date.day} ${_months[date.month - 1]}';

  /// Es. `gio` (giorno della settimana abbreviato, per il badge di una card).
  static String weekdayShort(DateTime date) => _weekdays[date.weekday - 1];

  /// Es. `lug` (mese abbreviato, per il badge di una card).
  static String monthShort(DateTime date) => _months[date.month - 1];

  /// "HH:mm" -> minuti dalla mezzanotte. `null` se la stringa non è valida.
  static int? _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// True se il turno finisce il giorno dopo (turno notturno, es. 22:00→02:00).
  /// Orari uguali NON sono notturni (durata zero, gestita altrove).
  static bool isOvernight(String startTime, String endTime) {
    final start = _toMinutes(startTime);
    final end = _toMinutes(endTime);
    if (start == null || end == null) return false;
    return end < start;
  }

  /// Intervallo orario di un turno, es. `22:00–02:00 (+1)` per i turni che
  /// scavalcano la mezzanotte. Fonte unica per mostrare gli orari nelle card.
  static String timeRange(String startTime, String endTime) {
    final suffix = isOvernight(startTime, endTime) ? ' (+1)' : '';
    return '$startTime–$endTime$suffix';
  }

  /// Iniziale maiuscola del giorno della settimana (`L`, `M`, `M`, `G`, …):
  /// riga dei giorni del calendario mensile.
  static String dowLetter(DateTime date) =>
      _weekdays[date.weekday - 1][0].toUpperCase();
}
