import 'package:cloud_firestore/cloud_firestore.dart';

/// Cosa fare del turno collegato quando il Responsabile APPROVA una richiesta
/// (RF6, "aggiornamento automatico del turno in caso di approvazione").
///
/// - [keep]:     il turno resta invariato (comportamento neutro);
/// - [reassign]: il turno passa a un altro dipendente (flusso alt. di UC4);
/// - [remove]:   il turno viene eliminato (l'autore non lo lavora più).
enum ShiftResolution { keep, reassign, remove }

/// Rappresenta il documento `restaurants/{rid}/leaveRequests/{requestId}`:
/// una richiesta di permesso o cambio turno inviata da un dipendente.
///
/// `type` vale "permesso" o "cambio_turno" (vedi LeaveType); `status` segue
/// il ciclo "in_attesa" -> "approvata" | "rifiutata" (vedi LeaveStatus).
class LeaveRequest {
  final String id;
  final String employeeUid;
  final String type;
  final String? relatedShiftId;
  final String? reason;
  final String status;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  const LeaveRequest({
    required this.id,
    required this.employeeUid,
    required this.type,
    this.relatedShiftId,
    this.reason,
    required this.status,
    this.createdAt,
    this.resolvedAt,
    this.resolvedBy,
  });

  factory LeaveRequest.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return LeaveRequest(
      id: doc.id,
      employeeUid: data['employeeUid'] as String? ?? '',
      type: data['type'] as String? ?? '',
      relatedShiftId: data['relatedShiftId'] as String?,
      reason: data['reason'] as String?,
      status: data['status'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      resolvedBy: data['resolvedBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'employeeUid': employeeUid,
    'type': type,
    'relatedShiftId': relatedShiftId,
    'reason': reason,
    'status': status,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
    'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
    'resolvedBy': resolvedBy,
  };
}
