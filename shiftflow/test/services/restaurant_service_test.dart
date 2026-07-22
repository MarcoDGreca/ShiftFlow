import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiftflow/core/constants/app_constants.dart';
import 'package:shiftflow/services/restaurant_service.dart';

/// Test della logica di anagrafica di [RestaurantService] contro un fake
/// Firestore in memoria: disattivazione (UC5-E2, richieste in attesa ->
/// decadute) e rimozione di un membro (turni futuri eliminati, storico
/// "fotografato", richieste in attesa decadute, documento staff eliminato).
void main() {
  const rid = 'r1';

  late FakeFirebaseFirestore db;
  late RestaurantService service;

  DocumentReference<Map<String, dynamic>> staff(String uid) => db
      .collection(FirestoreCollections.restaurants)
      .doc(rid)
      .collection(FirestoreCollections.staff)
      .doc(uid);

  CollectionReference<Map<String, dynamic>> requests() => db
      .collection(FirestoreCollections.restaurants)
      .doc(rid)
      .collection(FirestoreCollections.leaveRequests);

  CollectionReference<Map<String, dynamic>> shifts() => db
      .collection(FirestoreCollections.restaurants)
      .doc(rid)
      .collection(FirestoreCollections.shifts);

  Future<void> seedRequest(
    String id, {
    required String status,
    String employeeUid = 'emp1',
    String employeeName = 'Mario',
  }) => requests().doc(id).set({
    'employeeUid': employeeUid,
    'employeeName': employeeName,
    'type': LeaveType.permesso,
    'status': status,
  });

  Future<void> seedShift(
    String id, {
    required DateTime date,
    String employeeUid = 'emp1',
    String employeeName = 'Mario',
    String startTime = '18:00',
  }) => shifts().doc(id).set({
    'employeeUid': employeeUid,
    'employeeName': employeeName,
    'date': Timestamp.fromDate(date),
    'startTime': startTime,
    'endTime': '23:00',
    'createdBy': 'mgr',
  });

  setUp(() {
    db = FakeFirebaseFirestore();
    service = RestaurantService(db);
  });

  group('setStaffActive', () {
    test('disattivazione: chiude come "decaduta" le sole richieste in attesa',
        () async {
      await staff('emp1').set({'name': 'Mario', 'status': StaffStatus.attivo});
      await seedRequest('pending', status: LeaveStatus.inAttesa);
      await seedRequest('approvata', status: LeaveStatus.approvata);

      await service.setStaffActive(rid, 'emp1', active: false);

      expect(
        (await staff('emp1').get()).data()!['status'],
        StaffStatus.disattivato,
      );
      final pending = (await requests().doc('pending').get()).data()!;
      expect(pending['status'], LeaveStatus.decaduta);
      expect(pending['resolvedAt'], isNotNull);
      // La richiesta già decisa non viene toccata.
      expect(
        (await requests().doc('approvata').get()).data()!['status'],
        LeaveStatus.approvata,
      );
    });

    test('riattivazione: cambia solo lo stato, non tocca le richieste', () async {
      await staff('emp1').set({
        'name': 'Mario',
        'status': StaffStatus.disattivato,
      });
      await seedRequest('pending', status: LeaveStatus.inAttesa);

      await service.setStaffActive(rid, 'emp1', active: true);

      expect((await staff('emp1').get()).data()!['status'], StaffStatus.attivo);
      expect(
        (await requests().doc('pending').get()).data()!['status'],
        LeaveStatus.inAttesa,
      );
    });
  });

  group('removeStaff', () {
    test(
        'elimina i turni futuri, fotografa il nome sullo storico, decade le '
        'richieste in attesa ed elimina il documento staff', () async {
      final now = DateTime.now();
      await staff('emp1').set({'name': 'Mario', 'status': StaffStatus.attivo});
      await seedShift('futuro', date: now.add(const Duration(days: 2)));
      await seedShift(
        'passato',
        date: now.subtract(const Duration(days: 2)),
        employeeName: '', // verrà "fotografato" col nome passato
      );
      await seedRequest('pending', status: LeaveStatus.inAttesa, employeeName: '');
      await seedRequest(
        'approvata',
        status: LeaveStatus.approvata,
        employeeName: '',
      );

      await service.removeStaff(rid, 'emp1', name: 'Mario');

      // Turno futuro eliminato; turno passato conservato con nome fotografato.
      expect((await shifts().doc('futuro').get()).exists, isFalse);
      final passato = (await shifts().doc('passato').get()).data()!;
      expect(passato['employeeName'], 'Mario');

      // Richiesta in attesa -> decaduta + nome fotografato.
      final pending = (await requests().doc('pending').get()).data()!;
      expect(pending['status'], LeaveStatus.decaduta);
      expect(pending['resolvedAt'], isNotNull);
      expect(pending['employeeName'], 'Mario');

      // Richiesta già decisa: nome fotografato ma stato invariato.
      final approvata = (await requests().doc('approvata').get()).data()!;
      expect(approvata['status'], LeaveStatus.approvata);
      expect(approvata['employeeName'], 'Mario');

      // Documento anagrafica rimosso.
      expect((await staff('emp1').get()).exists, isFalse);
    });
  });
}
