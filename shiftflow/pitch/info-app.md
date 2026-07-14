# ShiftFlow — informazioni per il pitch

## In una frase

**ShiftFlow è l'app che semplifica la gestione dei turni nei ristoranti:
il responsabile pianifica, il dipendente consulta e chiede — tutto dal telefono,
in tempo reale.**

## Il problema

Nei locali la gestione dei turni vive ancora su fogli appesi in bacheca,
messaggi WhatsApp e telefonate: i dipendenti scoprono i turni all'ultimo,
le richieste di ferie si perdono, il responsabile ricompone tutto a mano.

## La soluzione

Un'unica app con due esperienze su misura:

### Per il responsabile
- **Calendario turni**: crea, modifica ed elimina i turni del locale con vista mensile.
- **Gestione personale**: aggiunge dipendenti (con creazione account), li attiva,
  disattiva o rimuove senza perdere lo storico.
- **Richieste in un posto solo**: approva o rifiuta ferie, permessi e cambi turno,
  con motivazione.

### Per il dipendente
- **I miei turni**: prossimo turno in evidenza (hero) + elenco e calendario.
- **Richieste**: ferie (intervallo di giorni), permessi (giorno singolo, anche a ore),
  cambio turno; può annullare quelle ancora in attesa.
- **Stato sempre chiaro**: chip colorati per in attesa / approvata / rifiutata /
  annullata / decaduta.

### Per entrambi
- Aggiornamenti **in tempo reale** (stream Firestore) e **funzionamento offline**
  con banner di stato sincronizzazione.
- **Notifiche** sugli eventi rilevanti.
- **Dark mode** completa e profilo modificabile.

## Come è fatta (tech)

- **Flutter** (un solo codice per iOS e Android), font Manrope, design system
  custom "glass" con gradiente ambientale.
- **Firebase**: Authentication (ruoli responsabile/dipendente), Cloud Firestore
  (dati in tempo reale + offline), regole di sicurezza per-ruolo.
- **Architettura a 4 livelli**: modelli → servizi → provider (state management)
  → schermate/widget. 62 file Dart.
- **Modello dati**: `restaurants/{id}` con subcollection `staff`, `shifts`,
  `leaveRequests`; utenti globali in `users`.

## Numeri di qualità (aggiornati al 14/07/2026)

- `flutter analyze`: **0 problemi**
- Test Flutter (unit + widget): **29/29 passati**
- Test regole di sicurezza Firestore: **24/24 passati** (7 suite, con emulatore)
- Accessibilità: coppie colore container/testo a contrasto **≥ 4.5:1 (WCAG AA)**,
  logo con etichetta semantica per screen reader
