/// Validatori riutilizzabili per i campi dei form.
///
/// Sono funzioni "pure" (nessuna dipendenza da Firebase o dalla UI): ricevono
/// il testo digitato e restituiscono `null` se è valido, oppure il messaggio
/// d'errore da mostrare. È esattamente la firma che si aspetta il parametro
/// `validator` di `TextFormField`. Essendo pure, sono anche facili da testare.
class Validators {
  Validators._();

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return "Inserisci l'email.";
    // Controllo volutamente semplice: "qualcosa@qualcosa.qualcosa".
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(v)) return 'Email non valida.';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Inserisci la password.';
    if (v.length < 6) return 'La password deve avere almeno 6 caratteri.';
    return null;
  }

  /// Validatore generico per campi di testo obbligatori.
  /// [field] serve a comporre il messaggio (es. "Il nome è obbligatorio.").
  static String? notEmpty(String? value, {String field = 'Il campo'}) {
    if ((value ?? '').trim().isEmpty) return '$field è obbligatorio.';
    return null;
  }
}
