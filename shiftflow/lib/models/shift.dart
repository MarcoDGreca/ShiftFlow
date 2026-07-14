import 'package:cloud_firestore/cloud_firestore.dart';

/// Rappresenta il documento `restaurants/{rid}/shifts/{shiftId}`: un turno
/// assegnato a un dipendente.
///
/// `date` è il giorno del turno; `startTime`/`endTime` sono orari in formato
/// stringa (es. "18:00"), tenuti separati per semplicità di input/visualizzazione.
class Shift {
  final String id;
  final String employeeUid;

  /// Nome del dipendente "fotografato" alla creazione (denormalizzazione).
  ///
  /// L'anagrafica (`staff/{uid}`) può sparire quando un membro viene rimosso
  /// dal locale: senza questa copia lo storico non saprebbe più chi ha
  /// lavorato il turno. Il nome "vivo" dall'anagrafica resta preferito quando
  /// disponibile (segue eventuali rinomine); questo è il paracadute.
  final String employeeName;

  final DateTime date;
  final String startTime;
  final String endTime;
  final String? notes;
  final String createdBy;
  final DateTime? createdAt;

  const Shift({
    required this.id,
    required this.employeeUid,
    this.employeeName = '',
    required this.date,
    required this.startTime,
    required this.endTime,
    this.notes,
    required this.createdBy,
    this.createdAt,
  });

  factory Shift.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Shift(
      id: doc.id,
      employeeUid: data['employeeUid'] as String? ?? '',
      employeeName: data['employeeName'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime(1970),
      startTime: data['startTime'] as String? ?? '',
      endTime: data['endTime'] as String? ?? '',
      notes: data['notes'] as String?,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'employeeUid': employeeUid,
    'employeeName': employeeName,
    'date': Timestamp.fromDate(date),
    'startTime': startTime,
    'endTime': endTime,
    'notes': notes,
    'createdBy': createdBy,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
  };

  /// True se il turno deve ancora iniziare rispetto a [moment]: combina il
  /// giorno [date] con l'orario [startTime] ("HH:mm").
  ///
  /// Serve alla rimozione di un membro: i turni non ancora iniziati vengono
  /// eliminati, quelli già svolti o in corso restano nello storico. Un orario
  /// non interpretabile conta come "già iniziato": nel dubbio si conserva.
  bool startsAfter(DateTime moment) {
    final parts = startTime.split(':');
    if (parts.length != 2) return false;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return false;
    final start = DateTime(date.year, date.month, date.day, hour, minute);
    return start.isAfter(moment);
  }

  /// Copia del turno con data diversa: serve alla ripetizione settimanale
  /// (stesso turno spostato di 7, 14, … giorni).
  Shift copyWithDate(DateTime newDate) => Shift(
    id: id,
    employeeUid: employeeUid,
    employeeName: employeeName,
    date: newDate,
    startTime: startTime,
    endTime: endTime,
    notes: notes,
    createdBy: createdBy,
    createdAt: createdAt,
  );
}
