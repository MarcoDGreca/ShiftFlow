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

  /// Iniziale maiuscola del giorno della settimana (`L`, `M`, `M`, `G`, …):
  /// riga dei giorni del calendario mensile.
  static String dowLetter(DateTime date) =>
      _weekdays[date.weekday - 1][0].toUpperCase();
}
