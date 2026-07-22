import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiftflow/core/constants/app_constants.dart';
import 'package:shiftflow/models/leave_request.dart';
import 'package:shiftflow/services/leave_request_service.dart';

/// Test della logica transazionale di [LeaveRequestService] contro un fake
/// Firestore in memoria: approvazione/rifiuto, corsa con l'annullamento,
/// azioni sul turno collegato (keep/reassign/remove) e annullamento lato
/// dipendente. Non tocca rete né emulatore.
void main() {
  const rid = 'r1';

  late FakeFirebaseFirestore db;
  late LeaveRequestService service;

  CollectionReference<Map<String, dynamic>> requests() => db
      .collection(FirestoreCollections.restaurants)
      .doc(rid)
      .collection(FirestoreCollections.leaveRequests);

  CollectionReference<Map<String, dynamic>> shifts() => db
      .collection(FirestoreCollections.restaurants)
      .doc(rid)
      .collection(FirestoreCollections.shifts);

  DocumentReference<Map<String, dynamic>> staff(String uid) => db
      .collection(FirestoreCollections.restaurants)
      .doc(rid)
      .collection(FirestoreCollections.staff)
      .doc(uid);

  Future<void> seedRequest(
    String id, {
    required String status,
    String employeeUid = 'emp1',
    String employeeName = 'Mario',
    String type = LeaveType.permesso,
    String? relatedShiftId,
  }) => requests().doc(id).set({
    'employeeUid': employeeUid,
    'employeeName': employeeName,
    'type': type,
    'status': status,
    'relatedShiftId': ?relatedShiftId,
  });

  Future<void> seedShift(
    String id, {
    String employeeUid = 'emp1',
    String employeeName = 'Mario',
    DateTime? date,
    String startTime = '18:00',
    String endTime = '23:00',
  }) => shifts().doc(id).set({
    'employeeUid': employeeUid,
    'employeeName': employeeName,
    'date': Timestamp.fromDate(date ?? DateTime(2026, 7, 20)),
    'startTime': startTime,
    'endTime': endTime,
    'createdBy': 'mgr',
  });

  setUp(() {
    db = FakeFirebaseFirestore();
    service = LeaveRequestService(db);
  });

  group('resolveRequest — approvazione / rifiuto', () {
    test('approva una richiesta in attesa', () async {
      await seedRequest('req1', status: LeaveStatus.inAttesa);

      await service.resolveRequest(
        rid,
        'req1',
        approved: true,
        resolvedByUid: 'mgr',
      );

      final data = (await requests().doc('req1').get()).data()!;
      expect(data['status'], LeaveStatus.approvata);
      expect(data['resolvedBy'], 'mgr');
      expect(data['resolvedAt'], isNotNull);
    });

    test('rifiuta una richiesta in attesa', () async {
      await seedRequest('req1', status: LeaveStatus.inAttesa);

      await service.resolveRequest(
        rid,
        'req1',
        approved: false,
        resolvedByUid: 'mgr',
      );

      expect(
        (await requests().doc('req1').get()).data()!['status'],
        LeaveStatus.rifiutata,
      );
    });

    test('rifiuta se la richiesta è già stata annullata (vince chi scrive prima)',
        () async {
      await seedRequest('req1', status: LeaveStatus.annullata);

      expect(
        () => service.resolveRequest(
          rid,
          'req1',
          approved: true,
          resolvedByUid: 'mgr',
        ),
        throwsA(isA<LeaveRequestException>()),
      );
      // Lo stato non è cambiato.
      expect(
        (await requests().doc('req1').get()).data()!['status'],
        LeaveStatus.annullata,
      );
    });

    test('fallisce se la richiesta non esiste più', () async {
      expect(
        () => service.resolveRequest(
          rid,
          'inesistente',
          approved: true,
          resolvedByUid: 'mgr',
        ),
        throwsA(isA<LeaveRequestException>()),
      );
    });
  });

  group('resolveRequest — azione sul turno collegato (RF6)', () {
    test('keep: il turno collegato resta invariato', () async {
      await seedShift('s1', employeeUid: 'emp1', employeeName: 'Mario');
      await seedRequest(
        'req1',
        status: LeaveStatus.inAttesa,
        type: LeaveType.cambioTurno,
        relatedShiftId: 's1',
      );

      await service.resolveRequest(
        rid,
        'req1',
        approved: true,
        resolvedByUid: 'mgr',
        relatedShiftId: 's1',
        // shiftResolution default = keep
      );

      final shift = (await shifts().doc('s1').get()).data()!;
      expect(shift['employeeUid'], 'emp1');
      expect(shift['employeeName'], 'Mario');
    });

    test('remove: il turno collegato viene eliminato', () async {
      await seedShift('s1');
      await seedRequest(
        'req1',
        status: LeaveStatus.inAttesa,
        type: LeaveType.cambioTurno,
        relatedShiftId: 's1',
      );

      await service.resolveRequest(
        rid,
        'req1',
        approved: true,
        resolvedByUid: 'mgr',
        relatedShiftId: 's1',
        shiftResolution: ShiftResolution.remove,
      );

      expect((await shifts().doc('s1').get()).exists, isFalse);
    });

    test('reassign: usa il nome VIVO del nuovo assegnatario (ignora quello passato)',
        () async {
      await seedShift('s1', employeeUid: 'emp1', employeeName: 'Mario');
      await staff('emp2').set({'name': 'Nuovo', 'status': StaffStatus.attivo});
      await seedRequest(
        'req1',
        status: LeaveStatus.inAttesa,
        type: LeaveType.cambioTurno,
        relatedShiftId: 's1',
      );

      await service.resolveRequest(
        rid,
        'req1',
        approved: true,
        resolvedByUid: 'mgr',
        relatedShiftId: 's1',
        shiftResolution: ShiftResolution.reassign,
        reassignToUid: 'emp2',
        reassignToName: null, // non passato: deve arrivare dall'anagrafica
      );

      final shift = (await shifts().doc('s1').get()).data()!;
      expect(shift['employeeUid'], 'emp2');
      expect(shift['employeeName'], 'Nuovo');
    });

    test('reassign: ripiega sul nome passato se manca il documento staff',
        () async {
      await seedShift('s1', employeeUid: 'emp1', employeeName: 'Mario');
      await seedRequest(
        'req1',
        status: LeaveStatus.inAttesa,
        type: LeaveType.cambioTurno,
        relatedShiftId: 's1',
      );

      await service.resolveRequest(
        rid,
        'req1',
        approved: true,
        resolvedByUid: 'mgr',
        relatedShiftId: 's1',
        shiftResolution: ShiftResolution.reassign,
        reassignToUid: 'emp2', // nessun doc staff/emp2
        reassignToName: 'Fallback',
      );

      expect(
        (await shifts().doc('s1').get()).data()!['employeeName'],
        'Fallback',
      );
    });

    test('removeShiftIds: approvando ferie, i turni nel periodo vengono eliminati',
        () async {
      await seedShift('s1', date: DateTime(2026, 8, 1));
      await seedShift('s2', date: DateTime(2026, 8, 2));
      await seedShift('s3', date: DateTime(2026, 8, 3));
      await seedRequest(
        'req1',
        status: LeaveStatus.inAttesa,
        type: LeaveType.ferie,
      );

      await service.resolveRequest(
        rid,
        'req1',
        approved: true,
        resolvedByUid: 'mgr',
        removeShiftIds: ['s1', 's2'],
      );

      expect((await shifts().doc('s1').get()).exists, isFalse);
      expect((await shifts().doc('s2').get()).exists, isFalse);
      expect((await shifts().doc('s3').get()).exists, isTrue);
      expect(
        (await requests().doc('req1').get()).data()!['status'],
        LeaveStatus.approvata,
      );
    });
  });

  group('cancelRequest — annullamento lato dipendente', () {
    test('il dipendente annulla la propria richiesta in attesa', () async {
      await seedRequest('req1', status: LeaveStatus.inAttesa, employeeUid: 'emp1');

      await service.cancelRequest(rid, 'req1', employeeUid: 'emp1');

      expect(
        (await requests().doc('req1').get()).data()!['status'],
        LeaveStatus.annullata,
      );
    });

    test('non si può annullare la richiesta di un altro', () async {
      await seedRequest('req1', status: LeaveStatus.inAttesa, employeeUid: 'emp1');

      expect(
        () => service.cancelRequest(rid, 'req1', employeeUid: 'altro'),
        throwsA(isA<LeaveRequestException>()),
      );
      expect(
        (await requests().doc('req1').get()).data()!['status'],
        LeaveStatus.inAttesa,
      );
    });

    test('non si può annullare una richiesta già decisa', () async {
      await seedRequest('req1', status: LeaveStatus.approvata, employeeUid: 'emp1');

      expect(
        () => service.cancelRequest(rid, 'req1', employeeUid: 'emp1'),
        throwsA(isA<LeaveRequestException>()),
      );
    });
  });
}
