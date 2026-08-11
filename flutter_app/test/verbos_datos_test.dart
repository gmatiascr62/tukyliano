import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/constantes.dart';
import 'package:tukyliano/modelos/verbo.dart';

/// Los verbos que trae la app. Hasta ahora el asset era un stub con un solo
/// verbo y los de verdad vivían nada más que en el repo de datos, así que
/// ningún test los miraba: los dos errores de glosas que aparecieron los
/// encontró el alumno practicando. Con el asset completo se pueden revisar.
final _json = File('assets/verbos.json').readAsStringSync();
final _datos =
    DatosVerbos.desdeJson(jsonDecode(_json) as Map<String, dynamic>);

/// El pronombre con el que tiene que empezar la traducción de cada persona.
const _pronombres = {
  'io': 'yo',
  'tu': 'tú',
  'lui/lei': 'él/ella',
  'noi': 'nosotros',
  'voi': 'ustedes',
  'loro': 'ellos',
};

/// Los auxiliares del passato prossimo, en el orden de [_pronombres].
const _auxAvere = ['ho', 'hai', 'ha', 'abbiamo', 'avete', 'hanno'];
const _auxEssere = ['sono', 'sei', 'è', 'siamo', 'siete', 'sono'];

/// Formas del haber español. Ninguna se puede decir sola: "yo he" no es una
/// frase, le falta el participio. Como consigna para traducir pediría algo
/// que no existe, y es exactamente el error que tenía avere en presente.
const _auxiliaresEspanoles = {
  'he', 'has', 'ha', 'hemos', 'han',
  'había', 'habías', 'habíamos', 'habían', 'habré', 'habrá',
};

/// La traducción sin el pronombre de adelante.
///
/// Hay que sacarlo antes de partir por "/", porque la barra se usa para dos
/// cosas distintas: separa pronombres ("él/ella") y separa traducciones
/// alternativas ("tengo/he"). Sin esto, "él/ella hace" parece tener una
/// alternativa que es "él".
String _sinPronombre(String espanol) {
  for (final pronombre in _pronombres.values) {
    if (espanol.startsWith('$pronombre ')) {
      return espanol.substring(pronombre.length + 1);
    }
  }
  return espanol;
}

List<String> _alternativas(String espanol) =>
    _sinPronombre(espanol).split('/').map((a) => a.trim()).toList();

void main() {
  group('el asset de verbos', () {
    test('trae los verbos completos, no un stub', () {
      // Antes tenía uno solo y el resto llegaba por GitHub. Si volviera a
      // quedar a medias, los tests de abajo dejarían de revisar casi todo
      // sin fallar, que es la peor forma de perder una garantía.
      expect(_datos.verbos.length, greaterThanOrEqualTo(4));
      expect(_datos.version, greaterThan(0));
    });

    test('cada verbo cubre todos los tiempos que se pueden practicar', () {
      // Si faltara uno, el alumno lo tildaría en la selección y el sorteo no
      // encontraría nada que preguntar.
      for (final verbo in _datos.verbos.values) {
        for (final tiempo in tiemposDisponibles) {
          expect(verbo.tiempos.containsKey(tiempo), isTrue,
              reason: 'a ${verbo.nombre} le falta $tiempo');
        }
      }
    });

    test('cada tiempo trae las seis personas', () {
      for (final verbo in _datos.verbos.values) {
        for (final tiempo in verbo.tiempos.entries) {
          // El gerundio es una forma sola, sin personas.
          if (tiempo.key == tiempoGerundio) continue;
          expect(tiempo.value.keys, containsAll(_pronombres.keys),
              reason: '${verbo.nombre}/${tiempo.key}');
        }
      }
    });

    test('toda conjugación trae las dos lenguas', () {
      for (final verbo in _datos.verbos.values) {
        for (final tiempo in verbo.tiempos.entries) {
          for (final persona in tiempo.value.entries) {
            final donde = '${verbo.nombre}/${tiempo.key}/${persona.key}';
            expect(persona.value.italiano, isNotEmpty, reason: donde);
            expect(persona.value.espanol, isNotEmpty, reason: donde);
          }
        }
      }
    });

    test('el pronombre del español coincide con la persona', () {
      // Una fila corrida de lugar daría "yo" donde va "ustedes", y el alumno
      // contestaría bien y la app se lo marcaría mal.
      for (final verbo in _datos.verbos.values) {
        for (final tiempo in verbo.tiempos.entries) {
          if (tiempo.key == tiempoGerundio) continue;
          for (final persona in tiempo.value.entries) {
            final esperado = _pronombres[persona.key]!;
            expect(persona.value.espanol, startsWith('$esperado '),
                reason: '${verbo.nombre}/${tiempo.key}/${persona.key}');
          }
        }
      }
    });

    test('ninguna traducción ofrece algo que no se pueda decir solo', () {
      // La red de contención de los dos errores que aparecieron practicando:
      // "yo fui/estuve" apuntaba al verbo ir, y "ustedes tienen/han" pedía
      // "ustedes han", que no es una frase.
      for (final verbo in _datos.verbos.values) {
        for (final tiempo in verbo.tiempos.entries) {
          for (final persona in tiempo.value.entries) {
            for (final alternativa in _alternativas(persona.value.espanol)) {
              expect(
                _auxiliaresEspanoles.contains(alternativa),
                isFalse,
                reason: '${verbo.nombre}/${tiempo.key}/${persona.key}: '
                    '"$alternativa" sola no se dice',
              );
            }
          }
        }
      }
    });

    test('dos verbos distintos no comparten una traducción', () {
      // Con "yo fui" para essere y para andare, la pregunta tendría dos
      // respuestas válidas y una se marcaría mal. Hoy no pasa, pero con más
      // verbos aparece solo: prendere y bere son los dos "tomar".
      final quienUsa = <String, Set<String>>{};
      for (final verbo in _datos.verbos.values) {
        for (final tiempo in verbo.tiempos.entries) {
          for (final persona in tiempo.value.entries) {
            for (final alternativa in _alternativas(persona.value.espanol)) {
              if (alternativa.isEmpty) continue;
              final clave = '${persona.key}|$alternativa';
              (quienUsa[clave] ??= {}).add(verbo.nombre);
            }
          }
        }
      }

      final choques = {
        for (final e in quienUsa.entries)
          if (e.value.length > 1) e.key: e.value,
      };
      expect(choques, isEmpty, reason: 'la misma traducción en dos verbos');
    });

    test('el passato prossimo usa bien el auxiliar', () {
      // Es el tiempo con más forma de equivocarse: hay que elegir avere o
      // essere y después conjugar el auxiliar, no el verbo.
      for (final verbo in _datos.verbos.values) {
        final pp = verbo.tiempos['passato_prossimo']!;
        final primera = pp['io']!.italiano.split(' ').first;
        final auxiliares =
            _auxEssere.first == primera ? _auxEssere : _auxAvere;
        expect([..._auxAvere, ..._auxEssere], contains(primera),
            reason: '${verbo.nombre}: "$primera" no es un auxiliar');

        final personas = _pronombres.keys.toList();
        for (var i = 0; i < personas.length; i++) {
          final partes = pp[personas[i]]!.italiano.split(' ');
          expect(partes.length, greaterThanOrEqualTo(2),
              reason: '${verbo.nombre}/${personas[i]}: falta el participio');
          expect(partes.first, auxiliares[i],
              reason: '${verbo.nombre}/${personas[i]}: el auxiliar');
        }
      }
    });

    test('el participio concuerda solo cuando el auxiliar es essere', () {
      // Con avere el participio no se mueve (ho avuto, abbiamo avuto). Con
      // essere concuerda: sono stato pero siamo stati.
      for (final verbo in _datos.verbos.values) {
        final pp = verbo.tiempos['passato_prossimo']!;
        final participios = [
          for (final p in _pronombres.keys)
            pp[p]!.italiano.split(' ').sublist(1).join(' '),
        ];
        final conEssere =
            _auxEssere.first == pp['io']!.italiano.split(' ').first;

        if (conEssere) {
          // Los tres singulares iguales entre sí, y los tres plurales también.
          expect(participios.sublist(0, 3).toSet().length, 1,
              reason: verbo.nombre);
          expect(participios.sublist(3).toSet().length, 1,
              reason: verbo.nombre);
        } else {
          expect(participios.toSet().length, 1, reason: verbo.nombre);
        }
      }
    });

    test('el gerundio termina en -ando o -endo', () {
      for (final verbo in _datos.verbos.values) {
        final gerundio = verbo.tiempos[tiempoGerundio]![personaGerundio]!;
        expect(
          gerundio.italiano.endsWith('ando') ||
              gerundio.italiano.endsWith('endo'),
          isTrue,
          reason: '${verbo.nombre}: "${gerundio.italiano}"',
        );
      }
    });

    test('el nombre del verbo es un infinitivo', () {
      for (final nombre in _datos.verbos.keys) {
        expect(
          nombre.endsWith('are') ||
              nombre.endsWith('ere') ||
              nombre.endsWith('ire'),
          isTrue,
          reason: '"$nombre" no parece un infinitivo',
        );
      }
    });

    test('cada verbo trae su traducción', () {
      for (final verbo in _datos.verbos.values) {
        expect(verbo.traduccion, isNotEmpty, reason: verbo.nombre);
        // Si faltara, el modelo pone el nombre italiano y en la pantalla de
        // selección se leería "volere (volere)".
        expect(verbo.traduccion, isNot(verbo.nombre), reason: verbo.nombre);
      }
    });

    test('no hay dos personas con la misma forma en el mismo tiempo', () {
      // Salvo "sono", que de verdad es io y loro a la vez.
      for (final verbo in _datos.verbos.values) {
        for (final tiempo in verbo.tiempos.entries) {
          if (tiempo.key == tiempoGerundio) continue;
          final formas = tiempo.value.values.map((c) => c.italiano).toList();
          final repetidas = formas.length - formas.toSet().length;
          expect(repetidas, lessThanOrEqualTo(1),
              reason: '${verbo.nombre}/${tiempo.key}: $formas');
        }
      }
    });
  });
}
