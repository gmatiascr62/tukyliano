import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/modelos/verbo.dart';

void main() {
  test('parsea el esquema con tiempos', () {
    final datos = DatosVerbos.desdeJson(jsonDecode('''
      {
        "version": 4,
        "verbos": {
          "volere": {
            "traduccion": "querer",
            "tiempos": {
              "presente": {
                "io": {"italiano": "voglio", "espanol": "yo quiero"},
                "tu": {"italiano": "vuoi", "espanol": "tú quieres"}
              },
              "futuro_semplice": {
                "io": {"italiano": "vorrò", "espanol": "yo querré"}
              }
            }
          }
        }
      }
    ''') as Map<String, dynamic>);

    expect(datos.version, 4);
    expect(datos.verbos.length, 1);

    final volere = datos.verbos['volere']!;
    expect(volere.traduccion, 'querer');
    expect(volere.tiempos.keys, containsAll(['presente', 'futuro_semplice']));
    expect(volere.tiempos['presente']!['io']!.italiano, 'voglio');
    expect(volere.tiempos['futuro_semplice']!['io']!.espanol, 'yo querré');
  });

  test('no se rompe con datos viejos sin la clave "tiempos"', () {
    // Esquema anterior a la migración de tiempos: la app Kivy mostraba un
    // mensaje en vez de crashear, acá tiene que pasar lo mismo.
    final datos = DatosVerbos.desdeJson(jsonDecode('''
      {
        "version": 2,
        "verbos": {
          "volere": {
            "traduccion": "querer",
            "conjugaciones": {"io": "voglio"}
          }
        }
      }
    ''') as Map<String, dynamic>);

    final volere = datos.verbos['volere']!;
    expect(volere.tiempos, isEmpty);
    expect(volere.tieneAlgunTiempo(['presente']), isFalse);
  });

  test('si no viene la clave "verbos" toma el objeto entero', () {
    final datos = DatosVerbos.desdeJson(jsonDecode('''
      {"fare": {"traduccion": "hacer", "tiempos": {}}}
    ''') as Map<String, dynamic>);

    expect(datos.verbos.containsKey('fare'), isTrue);
    expect(datos.version, 1);
  });

  test('usa el nombre del verbo si falta la traducción', () {
    final datos = DatosVerbos.desdeJson(
        jsonDecode('{"verbos": {"essere": {}}}') as Map<String, dynamic>);

    expect(datos.verbos['essere']!.traduccion, 'essere');
  });

  test('tieneAlgunTiempo detecta los tiempos disponibles', () {
    final datos = DatosVerbos.desdeJson(jsonDecode('''
      {"verbos": {"essere": {"tiempos": {
        "imperfetto": {"io": {"italiano": "ero", "espanol": "yo era"}}
      }}}}
    ''') as Map<String, dynamic>);

    final essere = datos.verbos['essere']!;
    expect(essere.tieneAlgunTiempo(['presente', 'imperfetto']), isTrue);
    expect(essere.tieneAlgunTiempo(['presente']), isFalse);
  });
}
