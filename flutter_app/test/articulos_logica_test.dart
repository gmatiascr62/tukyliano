import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/logica/articulos.dart';
import 'package:tukyliano/modelos/articulo.dart';

Sustantivo _sustantivo({
  String italiano = 'libro',
  String espanol = 'libro',
  String genero = 'm',
  String clase = 'm_consonante',
}) =>
    Sustantivo(
      italiano: italiano,
      espanol: espanol,
      espanolGenero: genero,
      clase: ClaseArticulo(
        nombre: clase,
        determinativo: 'il',
        indeterminativo: 'un',
        determinativoPlural: 'i',
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

  group('conArticuloEspanol', () {
    test('usa el género del español, no el del italiano', () {
      // zaino es masculino en italiano, pero se pregunta "la mochila".
      expect(
        conArticuloEspanol(_sustantivo(
            italiano: 'zaino', espanol: 'mochila', genero: 'f')),
        'la mochila',
      );
      expect(conArticuloEspanol(_sustantivo()), 'el libro');
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
