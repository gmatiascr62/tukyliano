import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/logica/seleccion_azar.dart';
import 'package:tukyliano/modelos/verbo.dart';

DatosVerbos _datos(String json) =>
    DatosVerbos.desdeJson(jsonDecode(json) as Map<String, dynamic>);

void main() {
  group('aplicarTecla', () {
    test('agrega letras', () {
      expect(aplicarTecla('son', 'o'), 'sono');
    });

    test('agrega espacio', () {
      expect(aplicarTecla('ho', teclaEspacio), 'ho ');
    });

    test('borra el último carácter', () {
      expect(aplicarTecla('sono', teclaBorrar), 'son');
    });

    test('borrar con el texto vacío no rompe', () {
      expect(aplicarTecla('', teclaBorrar), '');
    });

    test('acepta vocales acentuadas', () {
      expect(aplicarTecla('sar', 'ò'), 'sarò');
    });
  });

  group('elegirComboAzar', () {
    final conTiempos = _datos('''
      {"verbos": {
        "essere": {"traduccion": "ser/estar", "tiempos": {
          "presente": {"io": {"italiano": "sono", "espanol": "yo soy"}},
          "imperfetto": {"io": {"italiano": "ero", "espanol": "yo era"}}
        }},
        "avere": {"traduccion": "tener", "tiempos": {
          "presente": {"io": {"italiano": "ho", "espanol": "yo tengo"}}
        }}
      }}
    ''');

    test('devuelve null si ningún verbo tiene datos', () {
      final vacios = _datos('{"verbos": {"volere": {"traduccion": "querer"}}}');
      expect(elegirComboAzar(vacios.verbos.values, ['presente']), isNull);
    });

    test('devuelve null si la lista de verbos está vacía', () {
      expect(elegirComboAzar([], ['presente']), isNull);
    });

    test('solo elige tiempos que el verbo tenga cargados', () {
      // avere solo tiene presente: pidiendo ambos, nunca puede salir imperfetto.
      final soloAvere = [conTiempos.verbos['avere']!];
      for (var i = 0; i < 50; i++) {
        final combo = elegirComboAzar(
          soloAvere,
          ['presente', 'imperfetto'],
          azar: Random(i),
        );
        expect(combo!.tiempo, 'presente');
      }
    });

    test('descarta los verbos sin datos para el tiempo pedido', () {
      // Solo essere tiene imperfetto.
      for (var i = 0; i < 50; i++) {
        final combo = elegirComboAzar(
          conTiempos.verbos.values,
          ['imperfetto'],
          azar: Random(i),
        );
        expect(combo!.verbo.nombre, 'essere');
        expect(combo.conjugacion.italiano, 'ero');
      }
    });

    test('la conjugación devuelta coincide con verbo/tiempo/persona', () {
      for (var i = 0; i < 50; i++) {
        final combo = elegirComboAzar(
          conTiempos.verbos.values,
          ['presente', 'imperfetto'],
          azar: Random(i),
        )!;
        final esperada =
            combo.verbo.tiempos[combo.tiempo]![combo.persona]!;
        expect(combo.conjugacion.italiano, esperada.italiano);
        expect(combo.conjugacion.espanol, esperada.espanol);
      }
    });

    test('con varios verbos válidos llegan a salir todos', () {
      final nombres = <String>{};
      for (var i = 0; i < 50; i++) {
        nombres.add(
          elegirComboAzar(conTiempos.verbos.values, ['presente'], azar: Random(i))!
              .verbo
              .nombre,
        );
      }
      expect(nombres, containsAll(['essere', 'avere']));
    });
  });

  group('elegirComboFiltrado', () {
    // essere tiene dos personas en presente, avere una sola.
    final varios = _datos('''
      {"verbos": {
        "essere": {"traduccion": "ser/estar", "tiempos": {
          "presente": {
            "io": {"italiano": "sono", "espanol": "yo soy"},
            "tu": {"italiano": "sei", "espanol": "tú eres"}
          }
        }},
        "avere": {"traduccion": "tener", "tiempos": {
          "presente": {"io": {"italiano": "ho", "espanol": "yo tengo"}}
        }}
      }}
    ''');

    test('sin filtro devuelve alguna de todas las combinaciones', () {
      expect(
        elegirComboFiltrado(varios.verbos.values, ['presente'], (_) => true,
            azar: Random(1)),
        isNotNull,
      );
    });

    test('solo devuelve las que pasan el filtro', () {
      bool soloSei(Combo c) => c.conjugacion.italiano == 'sei';

      for (var i = 0; i < 20; i++) {
        final combo = elegirComboFiltrado(
            varios.verbos.values, ['presente'], soloSei, azar: Random(i));
        expect(combo!.verbo.nombre, 'essere');
        expect(combo.persona, 'tu');
      }
    });

    test('devuelve null si ninguna pasa el filtro', () {
      expect(
        elegirComboFiltrado(varios.verbos.values, ['presente'], (_) => false),
        isNull,
      );
    });

    test('devuelve null si el tiempo pedido no existe en ningún verbo', () {
      expect(
        elegirComboFiltrado(varios.verbos.values, ['imperfetto'], (_) => true),
        isNull,
      );
    });

    test('con el filtro puesto sigue variando entre las que quedan', () {
      bool soloEssere(Combo c) => c.verbo.nombre == 'essere';

      final personas = <String>{};
      for (var i = 0; i < 40; i++) {
        personas.add(elegirComboFiltrado(
                varios.verbos.values, ['presente'], soloEssere, azar: Random(i))!
            .persona);
      }
      expect(personas, containsAll(['io', 'tu']));
    });

    test('la conjugación devuelta coincide con verbo/tiempo/persona', () {
      for (var i = 0; i < 30; i++) {
        final combo = elegirComboFiltrado(
            varios.verbos.values, ['presente'], (_) => true, azar: Random(i))!;
        final esperada = combo.verbo.tiempos[combo.tiempo]![combo.persona]!;
        expect(combo.conjugacion.italiano, esperada.italiano);
      }
    });
  });
}
