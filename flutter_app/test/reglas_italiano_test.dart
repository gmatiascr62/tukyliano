import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/logica/reglas_italiano.dart';

void main() {
  group('los acentos que todos se olvidan', () {
    test('perche va con acento', () {
      final errores = revisarItaliano('Non so perche');

      expect(errores.single.escrito.toLowerCase(), 'perche');
      expect(errores.single.va, 'perché');
      expect(italianoCorregido('Non so perche'), 'Non so perché');
    });

    test('piu, gia, cosi y puo también', () {
      expect(italianoCorregido('voglio piu caffe'), 'voglio più caffè');
      expect(italianoCorregido('sono gia qui'), 'sono già qui');
      expect(italianoCorregido('e cosi'), 'e così');
      expect(italianoCorregido('non si puo'), 'non si può');
    });

    test('una palabra que ya está bien no se toca', () {
      expect(hayQueCorregir('Non so perché'), isFalse);
      expect(italianoCorregido('Non so perché'), 'Non so perché');
    });
  });

  group('palabras en español que se cuelan', () {
    test('que, y, muy', () {
      expect(italianoCorregido('penso que si'), 'penso che si');
      expect(italianoCorregido('pane y vino'), 'pane e vino');
      expect(italianoCorregido('molto muy bene'), 'molto molto bene');
    });

    test('dice por qué está mal, en español', () {
      final errores = revisarItaliano('penso que si');

      expect(errores.single.porque, contains('español'));
      expect(errores.single.porque, contains('che'));
    });
  });

  group('los errores de siempre', () {
    test('"no" delante de un verbo es "non"', () {
      expect(italianoCorregido('no capisco'), 'non capisco');
      expect(italianoCorregido('no ho tempo'), 'non ho tempo');
    });

    test('pero "No, grazie" se queda como está', () {
      // "no" solo existe en italiano: lo que no existe es pegado al verbo.
      expect(hayQueCorregir('No, grazie'), isFalse);
      expect(hayQueCorregir('No'), isFalse);
    });

    test('la edad va con avere', () {
      expect(italianoCorregido('sono 20 anni'), 'ho 20 anni');
    });

    test('delante de vocal, el artículo se acorta', () {
      expect(italianoCorregido('il amico'), "l'amico");
      expect(italianoCorregido('la amica'), "l'amica");
      expect(italianoCorregido('lo amico'), "l'amico");
    });

    test('delante de consonante no se toca', () {
      expect(hayQueCorregir('il cane'), isFalse);
      expect(hayQueCorregir('la casa'), isFalse);
    });

    test('mi chiamo è Marco mezcla las dos formas', () {
      expect(italianoCorregido('mi chiamo è Marco'), 'mi chiamo Marco');
    });
  });

  group('lo que NO tiene que corregir', () {
    // Una corrección equivocada le enseña mal a alguien: es peor que no
    // corregir. Estas frases están bien y tienen que pasar limpias.
    for (final frase in [
      'Ciao! Come stai?',
      'Mi chiamo Matías e sono argentino',
      'Oggi ho mangiato una pizza con te',
      'Non capisco questa parola',
      'Vado al lavoro in bici',
      'Ho vent\'anni e studio italiano',
      'Mi piace molto il caffè',
      'No, grazie, sono a posto',
      'Il cane dorme sul divano',
      'Domani vado a casa di mia sorella',
    ]) {
      test('"$frase" está bien', () {
        expect(revisarItaliano(frase), isEmpty, reason: frase);
      });
    }
  });

  group('varios errores juntos', () {
    test('los encuentra a todos, sin repetir', () {
      final errores = revisarItaliano('no capisco perche perche');

      expect(errores.length, 2);
      expect(errores.map((e) => e.va), containsAll(['non capisco', 'perché']));
    });

    test('y los arregla todos de una', () {
      expect(
        italianoCorregido('no capisco que dice'),
        'non capisco che dice',
      );
    });
  });
}
