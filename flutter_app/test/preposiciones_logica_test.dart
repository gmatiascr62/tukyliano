import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/logica/articulos.dart';
import 'package:tukyliano/logica/preposiciones.dart';

void main() {
  group('contraer', () {
    test('las cinco filas de la tabla', () {
      expect(contraer('di', 'il'), 'del');
      expect(contraer('a', 'il'), 'al');
      expect(contraer('da', 'il'), 'dal');
      expect(contraer('in', 'il'), 'nel');
      expect(contraer('su', 'il'), 'sul');
    });

    test('las siete columnas', () {
      expect(contraer('in', 'il'), 'nel');
      expect(contraer('in', 'lo'), 'nello');
      expect(contraer('in', 'la'), 'nella');
      expect(contraer('in', "l'"), "nell'");
      expect(contraer('in', 'i'), 'nei');
      expect(contraer('in', 'gli'), 'negli');
      expect(contraer('in', 'le'), 'nelle');
    });

    test('per y con no se contraen con nada', () {
      for (final articulo in articulosDeterminados) {
        expect(contraer('per', articulo), isNull, reason: 'per + $articulo');
        expect(contraer('con', articulo), isNull, reason: 'con + $articulo');
      }
    });

    test('la tabla está completa: cinco por siete', () {
      for (final preposicion in preposicionesQueSeContraen) {
        for (final articulo in articulosDeterminados) {
          expect(contraer(preposicion, articulo), isNotNull,
              reason: '$preposicion + $articulo');
        }
      }
    });

    test('no hay dos casilleros con la misma forma', () {
      // Si los hubiera, separar() no podría saber de cuál viene.
      final formas = [
        for (final p in preposicionesQueSeContraen)
          for (final a in articulosDeterminados) contraer(p, a)!,
      ];
      expect(formas.toSet().length, formas.length);
    });
  });

  group('formasDe', () {
    test('una que se contrae trae la simple más las siete', () {
      expect(formasDe('a'),
          ['a', 'al', 'allo', 'alla', "all'", 'ai', 'agli', 'alle']);
    });

    test('una que no se contrae trae solo la simple', () {
      expect(formasDe('per'), ['per']);
      expect(formasDe('con'), ['con']);
    });
  });

  group('separar', () {
    test('deshace la contracción', () {
      expect(separar('nella'), (preposicion: 'in', articulo: 'la'));
      expect(separar('dagli'), (preposicion: 'da', articulo: 'gli'));
      expect(separar("dell'"), (preposicion: 'di', articulo: "l'"));
    });

    test('una preposición sola no trae artículo', () {
      expect(separar('in'), (preposicion: 'in', articulo: null));
      expect(separar('per'), (preposicion: 'per', articulo: null));
    });

    test('es la vuelta exacta de contraer', () {
      for (final p in preposicionesQueSeContraen) {
        for (final a in articulosDeterminados) {
          expect(separar(contraer(p, a)!), (preposicion: p, articulo: a));
        }
      }
    });

    test('lo que no es una preposición devuelve null', () {
      // "perla" es una palabra italiana, pero no es "per" contraído.
      expect(separar('perla'), isNull);
      expect(separar('cogli'), isNull);
      expect(separar(''), isNull);
    });
  });

  group('cuentaDe', () {
    test('arma la cuenta de la contracción', () {
      expect(cuentaDe('nella'), 'in + la = nella');
      expect(cuentaDe('sugli'), 'su + gli = sugli');
    });

    test('sin contracción no hay cuenta que mostrar', () {
      expect(cuentaDe('in'), isNull);
      expect(cuentaDe('per'), isNull);
      expect(cuentaDe('perla'), isNull);
    });
  });

  test('el partitivo de Articoli sale de esta misma tabla', () {
    // Si algún día se tocara una, la otra tiene que moverse igual.
    for (final articulo in articulosDeterminados) {
      expect(partitivoDe(articulo), contraer('di', articulo));
    }
  });
}
