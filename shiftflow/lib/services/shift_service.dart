import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/shift.dart';

/// Turni + stato di sincronizzazione dello snapshot da cui provengono (RNF4).
///
/// - [isFromCache]: i dati arrivano dalla cache locale (tipicamente offline);
/// - [hasPendingWrites]: ci sono scritture locali non ancora confermate dal
///   server (accodate, verranno propagate al ritorno della rete, §7.1).
class ShiftsView {
  final List<Shift> shifts;
  final bool isFromCache;
  final bool hasPendingWrites;

  const ShiftsView(
    this.shifts, {
    this.isFromCache = false,
    this.hasPendingWrites = false,
  });
}

/// Wrapper Firestore per i turni (`restaurants/{rid}/shifts`).
class ShiftService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Riferimento alla subcollection dei turni di un locale.
  CollectionReference<Map<String, dynamic>> _shiftsRef(String restaurantId) =>
      _db
          .collection(FirestoreCollections.restaurants)
          .doc(restaurantId)
          .collection(FirestoreCollections.shifts);

  /// Ordina per data e, a parità di giorno, per orario di inizio.
  ///
  /// L'ordinamento è fatto in memoria e non nella query: `where` + `orderBy`
  /// su campi diversi richiederebbe un indice composito su Firestore; con i
  /// volumi di un singolo locale non ne vale la pena.
  List<Shift> _sorted(List<Shift> shifts) {
    shifts.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      return a.startTime.compareTo(b.startTime);
    });
    return shifts;
  }

  /// Costruisce una [ShiftsView] da uno snapshot, leggendone anche i metadati
  /// di sincronizzazione.
  ShiftsView _view(QuerySnapshot<Map<String, dynamic>> snap) => ShiftsView(
    _sorted(snap.docs.map(Shift.fromFirestore).toList()),
    isFromCache: snap.metadata.isFromCache,
    hasPendingWrites: snap.metadata.hasPendingWrites,
  );

  /// Turni di un singolo dipendente (vista Dipendente).
  ///
  /// `includeMetadataChanges: true` fa riemettere lo stream anche quando cambia
  /// solo lo stato di sincronizzazione (es. una scrittura in coda che viene
  /// confermata), così la UI può aggiornare l'indicatore offline (RNF4).
  Stream<ShiftsView> watchShiftsForEmployee(
    String restaurantId,
    String employeeUid,
  ) {
    return _shiftsRef(restaurantId)
        .where('employeeUid', isEqualTo: employeeUid)
        .snapshots(includeMetadataChanges: true)
        .map(_view);
  }

  /// Tutti i turni del locale (calendario completo, vista Responsabile).
  Stream<ShiftsView> watchAllShifts(String restaurantId) {
    return _shiftsRef(
      restaurantId,
    ).snapshots(includeMetadataChanges: true).map(_view);
  }

  /// Turni del locale in un dato giorno (qualunque dipendente), lettura singola.
  /// Serve a mostrare al Dipendente i colleghi in servizio nel suo stesso turno
  /// (UC2). Query per intervallo su un solo campo: nessun indice composito.
  Future<List<Shift>> fetchShiftsOnDate(
    String restaurantId,
    DateTime day,
  ) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final snap = await _shiftsRef(restaurantId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
    return _sorted(snap.docs.map(Shift.fromFirestore).toList());
  }

  Future<void> createShift(String restaurantId, Shift shift) async {
    await _shiftsRef(restaurantId).add(shift.toFirestore());
  }

  /// Crea più turni in un colpo solo (ripetizione settimanale) con un batch
  /// atomico: o vengono creati tutti o nessuno. Così una rete che cade a metà
  /// non lascia la serie "a buchi".
  Future<void> createShifts(String restaurantId, List<Shift> shifts) async {
    final batch = _db.batch();
    for (final shift in shifts) {
      batch.set(_shiftsRef(restaurantId).doc(), shift.toFirestore());
    }
    await batch.commit();
  }

  Future<void> updateShift(String restaurantId, Shift shift) async {
    await _shiftsRef(restaurantId).doc(shift.id).update(shift.toFirestore());
  }

  Future<void> deleteShift(String restaurantId, String shiftId) async {
    await _shiftsRef(restaurantId).doc(shiftId).delete();
  }

  /// Cerca un turno **dello stesso dipendente**, nello stesso giorno, che si
  /// sovrapponga in orario a quello indicato. Restituisce il primo trovato o
  /// `null`. Serve a SEGNALARE la sovrapposizione, non a bloccarla (§7.3): la
  /// decisione spetta al responsabile.
  ///
  /// Il filtro per giorno e orario è fatto in memoria (niente indici compositi).
  /// Gli orari sono convertiti in minuti; un turno notturno (fine ≤ inizio, es.
  /// 22:00→02:00) viene esteso al giorno dopo aggiungendo 1440 minuti, così il
  /// confronto a intervalli resta corretto. `excludeShiftId` esclude il turno
  /// che si sta modificando.
  ///
  /// Limite noto e accettato: confrontiamo solo turni ancorati allo STESSO
  /// giorno, quindi una sovrapposizione tra un turno notturno e un turno del
  /// giorno successivo non viene rilevata. Trattandosi di un semplice avviso
  /// (non di un blocco), è un compromesso ragionevole.
  Future<Shift?> findOverlapping(
    String restaurantId, {
    required String employeeUid,
    required DateTime date,
    required String startTime,
    required String endTime,
    String? excludeShiftId,
  }) async {
    final snap = await _shiftsRef(
      restaurantId,
    ).where('employeeUid', isEqualTo: employeeUid).get();

    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    for (final doc in snap.docs) {
      if (doc.id == excludeShiftId) continue;
      final other = Shift.fromFirestore(doc);
      if (!sameDay(other.date, date)) continue;
      if (timesOverlap(startTime, endTime, other.startTime, other.endTime)) {
        return other;
      }
    }
    return null;
  }

  /// True se due turni ancorati allo stesso giorno si sovrappongono in orario.
  /// Gli orari sono "HH:mm"; un turno notturno (fine ≤ inizio) viene esteso al
  /// giorno dopo (+1440 min). Funzione pura: separata per essere testabile.
  static bool timesOverlap(
    String startA,
    String endA,
    String startB,
    String endB,
  ) {
    final (aStart, aEnd) = _range(startA, endA);
    final (bStart, bEnd) = _range(startB, endB);
    // Due intervalli si sovrappongono se: inizioA < fineB && inizioB < fineA.
    return aStart < bEnd && bStart < aEnd;
  }

  /// "HH:mm" -> [inizio, fine] in minuti, col notturno esteso al giorno dopo.
  static (int, int) _range(String start, String end) {
    final s = _minutes(start);
    var e = _minutes(end);
    if (e <= s) e += 1440; // finisce il giorno successivo
    return (s, e);
  }

  /// "HH:mm" -> minuti dalla mezzanotte (0 se la stringa non è valida).
  static int _minutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }
}
