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
}
