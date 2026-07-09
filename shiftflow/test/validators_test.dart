// Unit test dei validatori del form di login.
//
// Sono funzioni pure (niente Firebase, niente UI), quindi si testano
// direttamente senza dover avviare l'app.

import 'package:flutter_test/flutter_test.dart';
import 'package:shiftflow/core/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('vuota -> messaggio di errore', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('   '), isNotNull);
    });

    test('senza formato valido -> messaggio di errore', () {
      expect(Validators.email('marco'), isNotNull);
      expect(Validators.email('marco@'), isNotNull);
      expect(Validators.email('marco@dominio'), isNotNull);
    });

    test('email valida -> null', () {
      expect(Validators.email('marco@ristorante.it'), isNull);
    });
  });

  group('Validators.password', () {
    test('vuota -> messaggio di errore', () {
      expect(Validators.password(''), isNotNull);
    });

    test('troppo corta -> messaggio di errore', () {
      expect(Validators.password('123'), isNotNull);
    });

    test('almeno 6 caratteri -> null', () {
      expect(Validators.password('123456'), isNull);
    });
  });
}
