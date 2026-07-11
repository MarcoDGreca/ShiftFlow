/// Costanti condivise dell'app: nomi delle collection Firestore e valori
/// "enumerati" (ruoli, stati, tipi) usati nel modello dati.
///
/// Centralizzarli qui evita di scrivere stringhe "a mano" sparse nel codice
/// (dove un typo non verrebbe segnalato dal compilatore).
library;

/// Nomi delle collection/subcollection Firestore.
class FirestoreCollections {
  FirestoreCollections._(); // impedisce l'istanziazione: è solo un contenitore

  static const String users = 'users';
  static const String restaurants = 'restaurants';
  static const String staff = 'staff';
  static const String shifts = 'shifts';
  static const String leaveRequests = 'leaveRequests';
}

/// Ruoli possibili di un utente.
class UserRoles {
  UserRoles._();

  static const String dipendente = 'dipendente';
  static const String responsabile = 'responsabile';
}

/// Stato di un membro dello staff (anagrafica del locale).
class StaffStatus {
  StaffStatus._();

  static const String invitato = 'invitato';
  static const String attivo = 'attivo';
  static const String disattivato = 'disattivato'; // non riceve nuovi turni
}

/// Tipo di richiesta inviata da un dipendente.
class LeaveType {
  LeaveType._();

  static const String permesso = 'permesso';
  static const String cambioTurno = 'cambio_turno';
}

/// Stato di una richiesta di permesso / cambio turno.
class LeaveStatus {
  LeaveStatus._();

  static const String inAttesa = 'in_attesa';
  static const String approvata = 'approvata';
  static const String rifiutata = 'rifiutata';
  static const String annullata = 'annullata'; // ritirata dal dipendente
}
