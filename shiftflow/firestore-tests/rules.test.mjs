// Suite di test sulle regole di sicurezza Firestore (criterio RNF2 del brief).
//
// Gira contro l'EMULATORE Firestore: nessun dato reale viene toccato. Verifica
// l'isolamento multi-tenant, i permessi per ruolo e le regole nuove introdotte
// (annullamento richieste dal dipendente, ruolo/ristorante immutabili su users).
//
// Avvio:  npm test   (dentro la cartella firestore-tests/)
// Sotto il cofano lancia l'emulatore e poi `node --test`.

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

// Project id "demo-*": l'emulatore lo tratta come offline, senza credenziali.
const PROJECT_ID = 'demo-shiftflow';
const RULES = readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8');

let testEnv;

/** Firestore autenticato come un certo utente (uid). */
function as(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: RULES },
  });
});

after(async () => {
  await testEnv.cleanup();
});

// Prima di ogni test: pulizia + dati di partenza scritti con le regole DISATTIVATE.
// Due ristoranti (A e B) e alcuni utenti; un turno e una richiesta "in attesa" in A.
beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/managerA'),
      { restaurantId: 'restA', role: 'responsabile', name: 'Manager A' });
    await setDoc(doc(db, 'users/empA'),
      { restaurantId: 'restA', role: 'dipendente', name: 'Emp A' });
    await setDoc(doc(db, 'users/empA2'),
      { restaurantId: 'restA', role: 'dipendente', name: 'Emp A2' });
    await setDoc(doc(db, 'users/empB'),
      { restaurantId: 'restB', role: 'dipendente', name: 'Emp B' });
    // empRimosso: profilo users ancora presente, ma NESSUN documento staff
    // (è lo stato in cui resta un membro dopo la rimozione dall'anagrafica).
    await setDoc(doc(db, 'users/empRimosso'),
      { restaurantId: 'restA', role: 'dipendente', name: 'Emp Rimosso' });

    await setDoc(doc(db, 'restaurants/restA'), { name: 'Ristorante A', ownerUid: 'managerA' });
    await setDoc(doc(db, 'restaurants/restB'), { name: 'Ristorante B', ownerUid: 'managerB' });

    // managerC: PROPRIETARIO di restC (ownerUid) ma SENZA documento staff.
    // È lo stato di un locale creato/seedato a mano prima che le regole
    // esigessero il doc staff: il proprietario deve comunque accedere.
    await setDoc(doc(db, 'users/managerC'),
      { restaurantId: 'restC', role: 'responsabile', name: 'Manager C' });
    await setDoc(doc(db, 'restaurants/restC'), { name: 'Ristorante C', ownerUid: 'managerC' });
    await setDoc(doc(db, 'restaurants/restC/shifts/shiftC'),
      { employeeUid: 'managerC', date: new Date() });

    // Nell'app reale OGNI membro (responsabile compreso) ha il proprio
    // documento staff: il seed deve rispecchiarlo, perché l'appartenenza
    // effettiva al locale si verifica proprio sull'esistenza di questo doc.
    await setDoc(doc(db, 'restaurants/restA/staff/managerA'),
      { name: 'Manager A', role: 'responsabile', status: 'attivo' });
    await setDoc(doc(db, 'restaurants/restA/staff/empA'),
      { name: 'Emp A', role: 'dipendente', status: 'attivo' });
    await setDoc(doc(db, 'restaurants/restA/staff/empA2'),
      { name: 'Emp A2', role: 'dipendente', status: 'attivo' });
    await setDoc(doc(db, 'restaurants/restB/staff/empB'),
      { name: 'Emp B', role: 'dipendente', status: 'attivo' });
    await setDoc(doc(db, 'restaurants/restA/shifts/shift1'),
      { employeeUid: 'empA', date: new Date() });
    await setDoc(doc(db, 'restaurants/restA/leaveRequests/req1'),
      { employeeUid: 'empA', status: 'in_attesa', type: 'permesso' });
  });
});

describe('Isolamento multi-tenant (RNF2)', () => {
  it('un dipendente del ristorante A legge i turni del proprio locale', async () => {
    await assertSucceeds(getDoc(doc(as('empA'), 'restaurants/restA/shifts/shift1')));
  });

  it('un dipendente del ristorante B NON legge i turni del ristorante A', async () => {
    await assertFails(getDoc(doc(as('empB'), 'restaurants/restA/shifts/shift1')));
  });

  it('un dipendente del ristorante B NON legge il documento del ristorante A', async () => {
    await assertFails(getDoc(doc(as('empB'), 'restaurants/restA')));
  });

  it('un dipendente del ristorante B NON legge le richieste del ristorante A', async () => {
    await assertFails(getDoc(doc(as('empB'), 'restaurants/restA/leaveRequests/req1')));
  });
});

// Seconda clausola di RNF2: la separazione vale anche DENTRO lo stesso locale.
// req1 è di empA; empA2 è un collega dello stesso ristorante A.
describe('Motivazioni delle richieste: private tra colleghi (RNF2)', () => {
  it('un dipendente legge la PROPRIA richiesta', async () => {
    await assertSucceeds(getDoc(doc(as('empA'), 'restaurants/restA/leaveRequests/req1')));
  });

  it('un dipendente NON legge la richiesta di un COLLEGA dello stesso locale', async () => {
    await assertFails(getDoc(doc(as('empA2'), 'restaurants/restA/leaveRequests/req1')));
  });

  it('il responsabile legge le richieste del proprio locale', async () => {
    await assertSucceeds(getDoc(doc(as('managerA'), 'restaurants/restA/leaveRequests/req1')));
  });

  // Le regole non "filtrano" una lista: la consentono solo se la query è già
  // ristretta ai documenti leggibili. Verifichiamo i pattern usati dall'app.
  it('il dipendente PUÒ elencare le proprie richieste (query ristretta)', async () => {
    const col = collection(as('empA'), 'restaurants/restA/leaveRequests');
    await assertSucceeds(getDocs(query(col, where('employeeUid', '==', 'empA'))));
  });

  it('il dipendente NON può elencare tutte le richieste del locale (query a tappeto)', async () => {
    const col = collection(as('empA'), 'restaurants/restA/leaveRequests');
    await assertFails(getDocs(col));
  });

  it('il responsabile PUÒ elencare tutte le richieste del locale', async () => {
    const col = collection(as('managerA'), 'restaurants/restA/leaveRequests');
    await assertSucceeds(getDocs(col));
  });
});

describe('Anagrafica: solo il responsabile gestisce lo staff (RF8)', () => {
  it('un dipendente NON può disattivare un collega', async () => {
    await assertFails(
      updateDoc(doc(as('empA'), 'restaurants/restA/staff/empA2'),
        { status: 'disattivato' }),
    );
  });

  it('il responsabile può disattivare un membro dello staff', async () => {
    await assertSucceeds(
      updateDoc(doc(as('managerA'), 'restaurants/restA/staff/empA2'),
        { status: 'disattivato' }),
    );
  });
});

describe('Turni: solo il responsabile scrive', () => {
  it('un dipendente NON può creare turni', async () => {
    await assertFails(
      setDoc(doc(as('empA'), 'restaurants/restA/shifts/shiftX'), { employeeUid: 'empA' }),
    );
  });

  it('il responsabile può creare turni', async () => {
    await assertSucceeds(
      setDoc(doc(as('managerA'), 'restaurants/restA/shifts/shiftX'), { employeeUid: 'empA' }),
    );
  });
});

describe('users: ruolo e ristorante immutabili (anti privilege-escalation)', () => {
  it('un dipendente NON può auto-promuoversi a responsabile', async () => {
    await assertFails(updateDoc(doc(as('empA'), 'users/empA'), { role: 'responsabile' }));
  });

  it('un dipendente NON può spostarsi in un altro ristorante', async () => {
    await assertFails(updateDoc(doc(as('empA'), 'users/empA'), { restaurantId: 'restB' }));
  });

  it('un utente può aggiornare il proprio profilo senza toccare ruolo/ristorante', async () => {
    await assertSucceeds(updateDoc(doc(as('empA'), 'users/empA'), { name: 'Nuovo Nome' }));
  });

  it('un utente NON può leggere il profilo di un altro', async () => {
    await assertFails(getDoc(doc(as('empA'), 'users/empB')));
  });
});

describe('Richieste: creazione e decisione', () => {
  it('un dipendente può creare una propria richiesta', async () => {
    await assertSucceeds(
      setDoc(doc(as('empA'), 'restaurants/restA/leaveRequests/reqY'),
        { employeeUid: 'empA', status: 'in_attesa', type: 'permesso' }),
    );
  });

  it('un dipendente NON può creare una richiesta a nome di un altro', async () => {
    await assertFails(
      setDoc(doc(as('empA'), 'restaurants/restA/leaveRequests/reqX'),
        { employeeUid: 'empA2', status: 'in_attesa', type: 'permesso' }),
    );
  });

  it('il responsabile può approvare una richiesta in attesa', async () => {
    await assertSucceeds(
      updateDoc(doc(as('managerA'), 'restaurants/restA/leaveRequests/req1'),
        { status: 'approvata', resolvedBy: 'managerA' }),
    );
  });
});

// Un membro RIMOSSO conserva account Auth e profilo users (il client del
// responsabile non può cancellarli), ma senza documento staff non deve più
// accedere ai dati del locale. Il suo documento staff (assente) resta
// leggibile da lui: serve al gate dell'app per capire che è stato rimosso.
describe('Membro rimosso: niente accesso ai dati del locale', () => {
  it('NON legge i turni del locale', async () => {
    await assertFails(getDoc(doc(as('empRimosso'), 'restaurants/restA/shifts/shift1')));
  });

  it('NON legge il documento del locale', async () => {
    await assertFails(getDoc(doc(as('empRimosso'), 'restaurants/restA')));
  });

  it('NON può creare richieste', async () => {
    await assertFails(
      setDoc(doc(as('empRimosso'), 'restaurants/restA/leaveRequests/reqR'),
        { employeeUid: 'empRimosso', status: 'in_attesa', type: 'permesso' }),
    );
  });

  it('NON può elencare le proprie richieste', async () => {
    const col = collection(as('empRimosso'), 'restaurants/restA/leaveRequests');
    await assertFails(getDocs(query(col, where('employeeUid', '==', 'empRimosso'))));
  });

  it('NON legge il documento staff di un collega', async () => {
    await assertFails(getDoc(doc(as('empRimosso'), 'restaurants/restA/staff/empA2')));
  });

  it('PUÒ leggere il PROPRIO documento staff (assente): serve al gate', async () => {
    await assertSucceeds(getDoc(doc(as('empRimosso'), 'restaurants/restA/staff/empRimosso')));
  });
});

// La registrazione del responsabile scrive nell'ordine locale → staff → users:
// così l'app entra nella home solo quando tutto esiste già, e le regole
// possono esigere il documento staff per l'accesso ai dati.
describe('Registrazione responsabile (locale → staff → profilo)', () => {
  it('la sequenza completa riesce per un utente nuovo', async () => {
    const db = as('newOwner');
    await assertSucceeds(
      setDoc(doc(db, 'restaurants/restNew'), { name: 'Nuovo', ownerUid: 'newOwner' }));
    await assertSucceeds(
      setDoc(doc(db, 'restaurants/restNew/staff/newOwner'),
        { name: 'New Owner', role: 'responsabile', status: 'attivo' }));
    await assertSucceeds(
      setDoc(doc(db, 'users/newOwner'),
        { restaurantId: 'restNew', role: 'responsabile', name: 'New Owner' }));
  });

  it('un utente GIÀ registrato non può creare un altro locale', async () => {
    await assertFails(
      setDoc(doc(as('empA'), 'restaurants/restX'), { name: 'X', ownerUid: 'empA' }));
  });

  it('non si può creare un locale intestato a un altro utente', async () => {
    await assertFails(
      setDoc(doc(as('newOwner'), 'restaurants/restY'), { name: 'Y', ownerUid: 'altroUid' }));
  });
});

// Il proprietario del locale è identificato dal campo ownerUid del ristorante,
// non dal documento staff: non può essere rimosso, quindi il suo accesso non
// deve dipendere da quel doc (altrimenti resterebbe chiuso fuori dai suoi dati).
describe('Proprietario senza documento staff: accede comunque', () => {
  it('legge i turni del proprio locale', async () => {
    await assertSucceeds(getDoc(doc(as('managerC'), 'restaurants/restC/shifts/shiftC')));
  });

  it('legge il documento del proprio locale', async () => {
    await assertSucceeds(getDoc(doc(as('managerC'), 'restaurants/restC')));
  });

  it('può elencare i turni del proprio locale', async () => {
    await assertSucceeds(getDocs(collection(as('managerC'), 'restaurants/restC/shifts')));
  });

  it('può creare turni nel proprio locale', async () => {
    await assertSucceeds(
      setDoc(doc(as('managerC'), 'restaurants/restC/shifts/shiftC2'),
        { employeeUid: 'managerC', date: new Date() }));
  });

  it('può creare il proprio documento staff (bootstrap)', async () => {
    await assertSucceeds(
      setDoc(doc(as('managerC'), 'restaurants/restC/staff/managerC'),
        { name: 'Manager C', role: 'responsabile', status: 'attivo' }));
  });

  it('un estraneo NON accede a restC', async () => {
    await assertFails(getDoc(doc(as('empB'), 'restaurants/restC/shifts/shiftC')));
  });
});

describe('Annullamento richiesta dal dipendente (§7.2)', () => {
  it('il dipendente può annullare la propria richiesta in attesa', async () => {
    await assertSucceeds(
      updateDoc(doc(as('empA'), 'restaurants/restA/leaveRequests/req1'),
        { status: 'annullata' }),
    );
  });

  it('il dipendente NON può approvare la propria richiesta', async () => {
    await assertFails(
      updateDoc(doc(as('empA'), 'restaurants/restA/leaveRequests/req1'),
        { status: 'approvata' }),
    );
  });

  it('un dipendente NON può annullare la richiesta di un collega', async () => {
    await assertFails(
      updateDoc(doc(as('empA2'), 'restaurants/restA/leaveRequests/req1'),
        { status: 'annullata' }),
    );
  });
});
