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

  Future<void> createShift(String restaurantId, Shift shift) async {
    await _shiftsRef(restaurantId).add(shift.toFirestore());
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
  /// Il filtro per giorno e orario è fatto in memoria (niente indici compositi):
  /// gli orari sono stringhe "HH:mm" zero-paddate, quindi confrontabili come
  /// testo. `excludeShiftId` esclude il turno che si sta modificando.
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
      // Due intervalli si sovrappongono se: inizioA < fineB && inizioB < fineA.
      if (startTime.compareTo(other.endTime) < 0 &&
          other.startTime.compareTo(endTime) < 0) {
        return other;
      }
    }
    return null;
  }
}
