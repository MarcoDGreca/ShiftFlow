# ShiftFlow — Differenze tra l'app e il RAD

> Documento di raccordo tra il **RAD** (`ShiftFlow_Requirements_Analysis_FINAL.pdf`)
> e lo **stato attuale dell'implementazione**.
> Aggiornato al **13 luglio 2026**. Riflette il codice corrente (non ancora committato).

Serve a due cose: sapere **cosa modificare nel RAD** perché il documento resti
veritiero, e avere l'elenco esplicito delle scelte prese in fase di realizzazione.

## Legenda

| Simbolo | Tipo di differenza |
|--------|--------------------|
| 🔴 | **Requisito rimosso / non implementato** — va tolto o segnato come fuori-MVP nel RAD |
| 🟠 | **Comportamento divergente** — l'app fa diversamente da quanto scritto |
| 🟢 | **Estensione** — l'app fa *di più* del RAD (funzioni non previste) |
| 🔵 | **Richiede backend** — non fattibile con il solo client Firebase (come le notifiche) |

---

## 1. Requisiti funzionali (§3.2)

### 🔴 RF7 — Notifiche push · **RIMOSSO**
- **RAD:** notifica push al destinatario su assegnazione turno, modifica turno ed esito richiesta (priorità *Must*).
- **App:** implementata solo la parte **client** (permessi, registrazione/rimozione token FCM in `users/{uid}.fcmTokens`). L'**invio** server→dispositivo **non esiste**: richiederebbe Cloud Functions.
- **Decisione:** requisito **abbandonato**.
- **Azione RAD:**
  - togliere **RF7** dalla tabella dei requisiti funzionali;
  - aggiornare **Obiettivo 1** e **Obiettivo 5** (§1.3), che citano RF7 nei criteri di successo;
  - rivedere i passi "invia notifica push" in **UC1, UC3, UC4** e i **diagrammi di sequenza** Fig. 3 e Fig. 4 (attore "Servizio di notifica");
  - valutare se rimuovere anche la classe **Notifica** dal modello degli oggetti (Fig. 2), oggi non persistita.
- **Nota tecnica:** il codice client FCM (`NotificationService`) resta in progetto come predisposizione, ma non è più collegato ad alcun requisito.

Tutti gli altri requisiti funzionali (**RF1–RF6, RF8, RF9, RF10, RF11**) sono implementati e allineati.

---

## 2. Casi d'uso — flussi ed eccezioni (§3.4.2)

### 🟠 UC1-E2 — Fine turno precedente all'inizio
- **RAD:** "l'orario di fine precede l'inizio → il sistema **rifiuta** il salvataggio".
- **App:** i turni a cavallo di mezzanotte (es. `22:00–02:00`) sono **ammessi** (interpretati come "finisce il giorno dopo"). Si rifiuta solo `fine == inizio` (durata zero).
- **Motivo:** i turni notturni sono reali per bar/ristoranti serali.
- **Azione RAD:** riscrivere UC1-E2 → "fine ≤ inizio è ammesso come turno notturno; si rifiuta solo fine uguale a inizio". Aggiornare di conseguenza il glossario ("Turno") e la voce "Sovrapposizione di turni".

### 🔵 UC5 — Onboarding del dipendente ("invitato" + credenziali)
- **RAD:** il sistema crea l'utenza in stato **"invitato"**, la associa al ristorante e **trasmette le credenziali di primo accesso**; UC5-E3 prevede il reinvio dell'invito.
- **App:** il responsabile crea direttamente l'account (tecnica dell'app Firebase secondaria) già in stato **"attivo"**, con **password scelta dal responsabile** e comunicata a voce. Non esiste invio email né stato "invitato" (la costante `invitato` esiste ma non è usata). Di conseguenza **UC5-E3** non è applicabile.
- **Motivo:** un vero flusso di invito via email richiede un backend (come le push).
- **Azione RAD:** o segnare l'invito via email come **fuori-MVP**, o documentare il flusso reale (creazione diretta con password provvisoria).

### 🟠 UC3 — Precondizione e oggetto della richiesta
- **RAD:** precondizione "il Dipendente **ha almeno un turno futuro assegnato**"; la richiesta è sempre **associata a un Turno**.
- **App:** **Permesso** e **Ferie** si possono chiedere **liberamente su una data/intervallo**, senza un turno collegato. Solo il **Cambio turno** resta legato a un turno.
- **Tipo:** questa è al tempo stesso un'estensione (vedi §3) e un allentamento della precondizione.
- **Azione RAD:** aggiornare precondizione e descrizione di UC3.

### ✅ Casi d'uso già riallineati (non più differenze)
Questi erano scoperti e ora sono **implementati** conformemente al RAD:
- **UC2, passo 3** — il dettaglio del turno del dipendente mostra data, orario, note **e i colleghi in servizio nello stesso turno**.
- **UC2-E1** — offline: oltre ai dati dalla cache, il banner mostra ora la **data dell'ultimo aggiornamento**.
- **UC4-E2** — l'opzione "Elimina il turno" in fase di approvazione **segnala esplicitamente la scopertura** ("il turno resterà scoperto"), senza impedirla.
- **UC5, flusso alternativo** — i turni futuri di un dipendente disattivato sono **segnalati "Da riassegnare"** sul calendario.
- **UC5-E2** — le richieste in attesa di un dipendente disattivato vengono **chiuse come "decadute"** (vedi §3).
- **UC1-E4** — al salvataggio il sistema **rifiuta l'assegnazione** di un turno a un dipendente disattivato nel frattempo.

---

## 3. Modello dei dati — oggetti e stati (§3.4.3 e §3.4.4)

### 🟢 Utente — campi anagrafici aggiuntivi
- **RAD (Fig. 2):** `id, nome, email, ristoranteId, stato`.
- **App:** aggiunge **`telefono`**, **`mansione`** (`position`) e **`data di nascita`** (`birthDate`), modificabili dall'utente stesso nella schermata Profilo. Tutti facoltativi e retrocompatibili.
- **Azione RAD:** aggiungere i tre attributi alla classe Utente (o segnarli come estensione).

### 🟢 Richiesta — tipo "ferie" e periodo
- **RAD (Fig. 2 + glossario):** `tipo` ∈ {permesso, cambio turno}; ogni Richiesta è **associata a un Turno** (`turnoId`).
- **App:** aggiunge il tipo **`ferie`** e i campi **`startDate`, `endDate`** (intervallo, per le ferie) e **`startTime`, `endTime`** (orario opzionale del permesso). `turnoId` (`relatedShiftId`) diventa **facoltativo** (nullo per ferie/permesso). Aggiunge anche `resolvedBy`.
- **Azione RAD:** aggiornare la classe Richiesta e il glossario ("Richiesta"), e rendere l'associazione con Turno **opzionale**.

### 🟠 Stato della richiesta — nuovo stato "decaduta"
- **RAD (Fig. 5):** stati = `in attesa → approvata | rifiutata | annullata` (quattro).
- **App:** aggiunge lo stato finale **`decaduta`** (richiesta chiusa d'ufficio perché il dipendente è stato disattivato mentre era in attesa — UC5-E2).
- **Azione RAD:** aggiungere lo stato **"decaduta"** al diagramma di stato Fig. 5 (transizione da "in attesa", causata dalla disattivazione del dipendente in UC5).

### 🟠 Turno — nessun campo "stato"
- **RAD (Fig. 2):** `Turno` ha `stato: StatoTurno`.
- **App:** il turno (`Shift`) **non ha un campo stato** (`id, employeeUid, date, startTime, endTime, note, createdBy, createdAt`). Il ciclo di vita del turno non è modellato con stati espliciti.
- **Azione RAD:** rimuovere `stato: StatoTurno` dalla classe Turno, oppure definirlo (non è mai stato dettagliato).

### 🟠 Multi-tenancy — `ristoranteId` come percorso, non come campo
- **RAD (Fig. 2):** `Turno` e `Richiesta` hanno `ristoranteId: String`.
- **App:** turni e richieste sono **subcollection** di `restaurants/{rid}/…`: l'appartenenza al locale è nel **percorso**, non in un campo del documento (solo `Utente` memorizza `restaurantId`, perché serve alle regole di sicurezza).
- **Tipo:** scelta implementativa (rafforza l'isolamento RF10/RNF2), diverge solo dalla rappresentazione grafica.
- **Azione RAD:** nota di modellazione facoltativa.

### 🔴 Notifica — classe non persistita
- **RAD (Fig. 2):** classe `Notifica` (`id, utenteId, tipo, messaggio, letta, dataInvio`).
- **App:** nessuna entità Notifica persistita (conseguenza della rimozione di RF7). Sul client si salvano solo i token FCM in `users/{uid}.fcmTokens`.
- **Azione RAD:** rimuovere la classe Notifica dal modello degli oggetti.

---

## 4. Requisiti non funzionali (§3.3)

### 🟠 RNF1 — Lingua italiana
- L'app è interamente in italiano. **Eccezione:** i selettori nativi di **data e ora** (Material) mostrano i **nomi dei mesi/giorni in inglese**, perché non sono installate le localizzazioni `flutter_localizations`. I pulsanti e i valori mostrati in app sono in italiano.
- **Azione:** facoltativa — aggiungere `flutter_localizations` + `locale: it` per localizzare anche i picker. Nessuna modifica al RAD.

### ⚪ RNF3 — Prestazioni (<2s p95 vista turni)
- **Non misurato.** Nessuna evidenza contraria, ma il criterio non è stato verificato con strumenti.

### ✅ RNF7 — Solo SDK Firebase
- I pacchetti aggiunti (`table_calendar`, `provider`, `cupertino_icons`, `flutter_launcher_icons`, `flutter_native_splash`) sono **librerie client** (UI/stato/build), **non servizi o API esterne**. Il font Manrope è **impacchettato localmente** (nessun download a runtime). Il criterio RNF7 resta soddisfatto.

Gli altri RNF (**RNF2 isolamento + test regole**, **RNF4 offline**, **RNF5 unico codice**, **RNF6 nuovo locale a soli dati**, **RNF8 packaging**) sono allineati.

---

## 5. Interfaccia e mock-up (§3.4.5)

- I mock-up del RAD sono dichiarati **a bassa fedeltà** ("non lo stile visivo finale"), quindi le differenze estetiche **non** sono divergenze di requisito.
- 🟢 **Redesign** completo (palette smeraldo, "liquid glass", tipografia Manrope, tema chiaro/scuro): scelta di implementazione, coerente col RAD.
- 🟠 **RF4 — vista calendario:** il mock-up 3 mostra una vista **settimanale**; l'app usa una griglia **mensile** (con pallini per turni e assenze). Copre comunque "il calendario complessivo del locale". Nota facoltativa.

---

## 6. Estensioni oltre il RAD (funzioni non previste dal documento)

Aggiunte richieste in corso d'opera, **non presenti nel RAD**. Vanno **documentate** nel RAD se si vuole che sia completo, oppure tenute come "extra".

- 🟢 **Ferie** come terzo tipo di richiesta (intervallo di giorni), con marcatura sui calendari.
- 🟢 **Permesso con data/orario liberi**, non legato a un turno.
- 🟢 **Assenze (ferie/permessi) mostrate sui calendari** — del responsabile (tutti) e del dipendente (solo le proprie), con legenda e dettaglio del giorno.
- 🟢 **Calendario dei propri turni per il dipendente** (oltre alla lista): il RAD prevedeva per il dipendente la sola lista ordinata (RF3).
- 🟢 **Profilo personale con dati modificabili** (telefono, mansione, data di nascita).

---

## 7. Checklist delle modifiche al RAD

Riepilogo operativo di ciò che va toccato nel documento:

- [ ] **RF7:** rimuovere il requisito.
- [ ] **Obiettivi 1 e 5 (§1.3):** togliere i riferimenti alle notifiche push.
- [ ] **UC1, UC3, UC4:** rimuovere i passi "invia notifica push".
- [ ] **Fig. 3 e Fig. 4 (sequenza):** rimuovere l'attore "Servizio di notifica".
- [ ] **Fig. 2 (oggetti):** rimuovere la classe **Notifica**; aggiungere a **Utente** (telefono, mansione, data di nascita); aggiornare **Richiesta** (tipo "ferie", date/orari, `turnoId` opzionale); rimuovere `stato` da **Turno**.
- [ ] **Fig. 5 (stati richiesta):** aggiungere lo stato **"decaduta"**.
- [ ] **UC1-E2:** riscrivere per ammettere i turni notturni.
- [ ] **UC3:** aggiornare precondizione e tipi di richiesta (aggiungere Ferie; permesso/ferie senza turno).
- [ ] **UC5:** allineare l'onboarding (invito email fuori-MVP oppure descrivere la creazione diretta).
- [ ] **Glossario:** aggiornare "Richiesta" (include le ferie) e "Turno" (turni notturni).

---

## 8. Cosa è invece pienamente allineato

Per chiarezza, il **nucleo del RAD è coperto**:

- **RF1–RF6, RF8–RF11** implementati.
- **RNF2** (isolamento multi-tenant e motivazioni private) con **suite di test** sulle regole Firestore.
- **RNF4** (offline), **RNF5** (unico codice Flutter Android/iOS), **RNF6** (nuovo locale a soli dati, nessun Firebase sopra i servizi).
- **UC1–UC5** con i rispettivi flussi principali, alternativi e di eccezione — salvo le differenze elencate sopra.

L'unico requisito *Must* del RAD non implementato è **RF7 (notifiche push)**, per scelta esplicita.
