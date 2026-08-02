import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/logica/articulos.dart';
import 'package:tukyliano/modelos/articulo.dart';

Sustantivo _sustantivo({
  String italiano = 'libro',
  String espanol = 'libro',
  String genero = 'm',
  String clase = 'm_consonante',
  String plural = '',
  String espanolPlural = '',
  bool incontable = false,
}) =>
    Sustantivo(
      italiano: italiano,
      espanol: espanol,
      espanolGenero: genero,
      italianoPlural: plural,
      espanolPlural: espanolPlural,
      incontable: incontable,
      clase: ClaseArticulo(
        nombre: clase,
        determinativo: 'il',
        indeterminativo: 'un',
        determinativoPlural: 'i',
        partitivo: 'del',
        partitivoPlural: 'dei',
        explicacion: '',
      ),
    );

void main() {
  group('unir', () {
    test('el artículo con apóstrofo va pegado', () {
      expect(unir("l'", 'amico'), "l'amico");
      expect(unir("un'", 'amica'), "un'amica");
    });

    test('el resto va con un espacio', () {
      expect(unir('lo', 'zaino'), 'lo zaino');
      expect(unir('il', 'libro'), 'il libro');
      expect(unir('gli', 'zaini'), 'gli zaini');
    });
  });

  group('la pregunta en español', () {
    test('usa el género del español, no el del italiano', () {
      // zaino es masculino en italiano, pero se pregunta "la mochila".
      final zaino = _sustantivo(
          italiano: 'zaino', espanol: 'mochila', genero: 'f');
      expect(
        Consigna(zaino, CategoriaArticulo.determinado).pregunta,
        'la mochila',
      );
      expect(
        Consigna(_sustantivo(), CategoriaArticulo.determinado).pregunta,
        'el libro',
      );
    });

    test('el artículo del español dice qué categoría se pide', () {
      final zaino = _sustantivo(
        italiano: 'zaino',
        espanol: 'mochila',
        genero: 'f',
        plural: 'zaini',
        espanolPlural: 'mochilas',
      );
      expect(Consigna(zaino, CategoriaArticulo.determinado).pregunta,
          'la mochila');
      expect(Consigna(zaino, CategoriaArticulo.indeterminado).pregunta,
          'una mochila');
      expect(Consigna(zaino, CategoriaArticulo.plural).pregunta,
          'las mochilas');
      expect(Consigna(zaino, CategoriaArticulo.partitivoPlural).pregunta,
          'unas mochilas');
    });

    test('el partitivo plural es el "unos/unas" que el italiano no tiene', () {
      final libro = _sustantivo(plural: 'libri', espanolPlural: 'libros');
      expect(Consigna(libro, CategoriaArticulo.partitivoPlural).pregunta,
          'unos libros');
    });

    test('el partitivo singular no lleva género', () {
      final pan = _sustantivo(
          italiano: 'pane', espanol: 'pan', incontable: true);
      final carne = _sustantivo(
          italiano: 'carne', espanol: 'carne', genero: 'f', incontable: true);

      expect(
          Consigna(pan, CategoriaArticulo.partitivo).pregunta, 'algo de pan');
      expect(Consigna(carne, CategoriaArticulo.partitivo).pregunta,
          'algo de carne');
    });
  });

  group('partitivoDe', () {
    test('contrae di con cada artículo determinado', () {
      expect(partitivoDe('il'), 'del');
      expect(partitivoDe('lo'), 'dello');
      expect(partitivoDe('la'), 'della');
      expect(partitivoDe("l'"), "dell'");
      expect(partitivoDe('i'), 'dei');
      expect(partitivoDe('gli'), 'degli');
      expect(partitivoDe('le'), 'delle');
    });

    test('no inventa nada con lo que no es un artículo', () {
      expect(partitivoDe('un'), isNull);
      expect(partitivoDe(''), isNull);
    });
  });

  group('la consigna según la categoría', () {
    final zaino = _sustantivo(
      italiano: 'zaino',
      espanol: 'mochila',
      genero: 'f',
      clase: 'm_s_impura',
      plural: 'zaini',
      espanolPlural: 'mochilas',
    );

    test('en plural se muestra la palabra en plural', () {
      expect(Consigna(zaino, CategoriaArticulo.determinado).palabra, 'zaino');
      expect(Consigna(zaino, CategoriaArticulo.plural).palabra, 'zaini');
    });

    test('el partitivo plural también muestra el plural', () {
      expect(
          Consigna(zaino, CategoriaArticulo.partitivoPlural).palabra, 'zaini');
    });

    test('cada categoría pide el artículo que le toca', () {
      // El helper arma la clase con il / un / del / i / dei.
      expect(Consigna(zaino, CategoriaArticulo.determinado).correcto, 'il');
      expect(Consigna(zaino, CategoriaArticulo.indeterminado).correcto, 'un');
      expect(Consigna(zaino, CategoriaArticulo.partitivo).correcto, 'del');
      expect(Consigna(zaino, CategoriaArticulo.plural).correcto, 'i');
      expect(Consigna(zaino, CategoriaArticulo.partitivoPlural).correcto,
          'dei');
    });

    test('la respuesta ya viene armada', () {
      expect(Consigna(zaino, CategoriaArticulo.plural).respuesta, 'i zaini');
      expect(Consigna(zaino, CategoriaArticulo.partitivoPlural).respuesta,
          'dei zaini');
    });
  });

  group('las opciones de cada categoría', () {
    test('el determinado y el indeterminado tienen cuatro', () {
      expect(CategoriaArticulo.determinado.opciones,
          ['il', 'lo', 'la', "l'"]);
      expect(CategoriaArticulo.indeterminado.opciones,
          ['un', 'uno', 'una', "un'"]);
    });

    test('el partitivo singular también tiene cuatro', () {
      expect(CategoriaArticulo.partitivo.opciones,
          ['del', 'dello', 'della', "dell'"]);
    });

    test('los plurales tienen tres: no distinguen vocal de consonante', () {
      // "gli" cubre tanto gli amici como gli zaini, así que no hay un cuarto.
      expect(CategoriaArticulo.plural.opciones, ['i', 'gli', 'le']);
      expect(CategoriaArticulo.partitivoPlural.opciones,
          ['dei', 'degli', 'delle']);
    });

    test('cada opción es la contracción de la del determinado', () {
      for (final (i, articulo)
          in CategoriaArticulo.determinado.opciones.indexed) {
        expect(CategoriaArticulo.partitivo.opciones[i], partitivoDe(articulo));
      }
      for (final (i, articulo) in CategoriaArticulo.plural.opciones.indexed) {
        expect(CategoriaArticulo.partitivoPlural.opciones[i],
            partitivoDe(articulo));
      }
    });

    test('solo los partitivos traen la ayuda extra', () {
      expect(CategoriaArticulo.partitivo.ayuda, isNotEmpty);
      expect(CategoriaArticulo.partitivoPlural.ayuda, isNotEmpty);
      expect(CategoriaArticulo.determinado.ayuda, isEmpty);
      expect(CategoriaArticulo.indeterminado.ayuda, isEmpty);
      expect(CategoriaArticulo.plural.ayuda, isEmpty);
    });

    test('esPartitivo distingue las dos', () {
      expect(CategoriaArticulo.partitivo.esPartitivo, isTrue);
      expect(CategoriaArticulo.partitivoPlural.esPartitivo, isTrue);
      expect(CategoriaArticulo.determinado.esPartitivo, isFalse);
    });
  });

  group('consignasPosibles', () {
    final conPlural = _sustantivo(
      italiano: 'zaino',
      espanol: 'mochila',
      genero: 'f',
      plural: 'zaini',
      espanolPlural: 'mochilas',
    );
    final sinPlural = _sustantivo(italiano: 'latte', espanol: 'leche');
    final incontable = _sustantivo(
        italiano: 'pane', espanol: 'pan', incontable: true);

    test('una palabra que se cuenta va en todo menos el partitivo singular',
        () {
      final consignas =
          consignasPosibles([conPlural], CategoriaArticulo.values.toSet());

      expect(consignas.map((c) => c.categoria), [
        CategoriaArticulo.determinado,
        CategoriaArticulo.indeterminado,
        CategoriaArticulo.plural,
        CategoriaArticulo.partitivoPlural,
      ]);
    });

    test('una palabra sin plural queda afuera de las dos categorías plurales',
        () {
      final consignas =
          consignasPosibles([sinPlural], CategoriaArticulo.values.toSet());

      expect(
        consignas.map((c) => c.categoria),
        [CategoriaArticulo.determinado, CategoriaArticulo.indeterminado],
      );
    });

    test('una incontable va al partitivo singular y no al indeterminado', () {
      // "algo de pan" sí, "un pan" no: para eso está el partitivo.
      final consignas =
          consignasPosibles([incontable], CategoriaArticulo.values.toSet());

      expect(
        consignas.map((c) => c.categoria),
        [CategoriaArticulo.determinado, CategoriaArticulo.partitivo],
      );
    });

    test('el partitivo singular no acepta palabras que se cuentan', () {
      // "del libro" es "del libro", no "algo de libro".
      expect(consignasPosibles([conPlural], {CategoriaArticulo.partitivo}),
          isEmpty);
    });

    test('sin el plural en español tampoco entra', () {
      // Si no, la pregunta quedaría "las " sin nada atrás.
      final aMedias = _sustantivo(italiano: 'zaino', plural: 'zaini');
      final consignas =
          consignasPosibles([aMedias], {CategoriaArticulo.plural});

      expect(consignas, isEmpty);
    });

    test('respeta las categorías que se le piden', () {
      final consignas = consignasPosibles(
          [conPlural, sinPlural], {CategoriaArticulo.determinado});

      expect(consignas.length, 2);
      expect(consignas.every((c) => c.categoria == CategoriaArticulo.determinado),
          isTrue);
    });

    test('sin categorías no hay preguntas', () {
      expect(consignasPosibles([conPlural], {}), isEmpty);
    });
  });

  group('generoEnganoso', () {
    test('detecta cuando el género no coincide con el español', () {
      final zaino = _sustantivo(
          italiano: 'zaino',
          espanol: 'mochila',
          genero: 'f',
          clase: 'm_s_impura');
      expect(zaino.generoEnganoso, isTrue);
    });

    test('es falso cuando coinciden', () {
      expect(_sustantivo().generoEnganoso, isFalse);
    });
  });

  group('claseDeducida', () {
    test('masculino con consonante común', () {
      expect(claseDeducida('libro', masculino: true), 'm_consonante');
      expect(claseDeducida('cane', masculino: true), 'm_consonante');
      expect(claseDeducida('tavolo', masculino: true), 'm_consonante');
    });

    test('masculino con s impura', () {
      expect(claseDeducida('studente', masculino: true), 'm_s_impura');
      expect(claseDeducida('specchio', masculino: true), 'm_s_impura');
      expect(claseDeducida('sbaglio', masculino: true), 'm_s_impura');
    });

    test('masculino con z, gn, ps, pn, x, y', () {
      expect(claseDeducida('zaino', masculino: true), 'm_s_impura');
      expect(claseDeducida('gnomo', masculino: true), 'm_s_impura');
      expect(claseDeducida('psicologo', masculino: true), 'm_s_impura');
      expect(claseDeducida('pneumatico', masculino: true), 'm_s_impura');
      expect(claseDeducida('xilofono', masculino: true), 'm_s_impura');
      expect(claseDeducida('yogurt', masculino: true), 'm_s_impura');
    });

    test('masculino con i semiconsonante', () {
      expect(claseDeducida('iodio', masculino: true), 'm_s_impura');
    });

    test('la s seguida de vocal no es impura', () {
      expect(claseDeducida('sole', masculino: true), 'm_consonante');
      expect(claseDeducida('sasso', masculino: true), 'm_consonante');
    });

    test('masculino con vocal', () {
      expect(claseDeducida('amico', masculino: true), 'm_vocal');
      expect(claseDeducida('albero', masculino: true), 'm_vocal');
      expect(claseDeducida('orso', masculino: true), 'm_vocal');
    });

    test('la h muda cuenta como vocal', () {
      expect(claseDeducida('hotel', masculino: true), 'm_vocal');
    });

    test('en femenino la consonante nunca importa', () {
      expect(claseDeducida('casa', masculino: false), 'f_consonante');
      // Empieza con s impura, pero en femenino igual va "la".
      expect(claseDeducida('scuola', masculino: false), 'f_consonante');
      expect(claseDeducida('zia', masculino: false), 'f_consonante');
    });

    test('femenino con vocal', () {
      expect(claseDeducida('amica', masculino: false), 'f_vocal');
      expect(claseDeducida('isola', masculino: false), 'f_vocal');
    });

    test('no se cuelga con una palabra vacía', () {
      expect(claseDeducida('', masculino: true), isNull);
    });
  });
}
