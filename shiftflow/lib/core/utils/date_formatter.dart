/// Helper di formattazione di date e orari.
///
/// Placeholder minimo: verrà ampliato quando costruiremo le schermate di
/// turni e calendario. Isolare qui la formattazione evita di ripetere la
/// stessa logica in più widget.
class DateFormatter {
  DateFormatter._();

  /// Es. `9/7/2026`.
  static String toDayLabel(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
}
