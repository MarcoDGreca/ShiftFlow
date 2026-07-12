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

    await setDoc(doc(db, 'restaurants/restA'), { name: 'Ristorante A', ownerUid: 'managerA' });
    await setDoc(doc(db, 'restaurants/restB'), { name: 'Ristorante B', ownerUid: 'managerB' });

    await setDoc(doc(db, 'restaurants/restA/staff/empA2'),
      { name: 'Emp A2', role: 'dipendente', status: 'attivo' });
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
