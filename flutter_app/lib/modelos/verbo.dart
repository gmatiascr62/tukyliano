/// Modelo del JSON de verbos. El esquema es el mismo que usa la app Kivy:
///
/// {
///   "version": 4,
///   "verbos": {
///     "volere": {
///       "traduccion": "querer",
///       "tiempos": {
///         "presente": {"io": {"italiano": "voglio", "espanol": "yo quiero"}, ...}
///       }
///     }
///   }
/// }
///
/// El parseo es tolerante a propósito: hay datos viejos dando vueltas sin la
/// clave "tiempos", y la app tiene que mostrar un mensaje en vez de romperse.
library;

import '../constantes.dart';

class Conjugacion {
  const Conjugacion({required this.italiano, required this.espanol});

  final String italiano;
  final String espanol;

  factory Conjugacion.desdeJson(Map<String, dynamic> json) {
    return Conjugacion(
      italiano: json['italiano'] as String? ?? '',
      espanol: json['espanol'] as String? ?? '',
    );
  }
}

class Verbo {
  const Verbo({
    required this.nombre,
    required this.traduccion,
    required this.tiempos,
  });

  final String nombre;
  final String traduccion;

  /// tiempo -> persona -> conjugación
  final Map<String, Map<String, Conjugacion>> tiempos;

  bool tieneAlgunTiempo(List<String> cuales) =>
      cuales.any(tiempos.containsKey);

  factory Verbo.desdeJson(String nombre, Map<String, dynamic> json) {
    final tiemposJson = json['tiempos'];
    final tiempos = <String, Map<String, Conjugacion>>{};

    if (tiemposJson is Map<String, dynamic>) {
      tiemposJson.forEach((tiempo, personas) {
        if (personas is Map<String, dynamic>) {
          final porPersona = <String, Conjugacion>{};
          personas.forEach((persona, datos) {
            if (datos is Map<String, dynamic>) {
              porPersona[persona] = Conjugacion.desdeJson(datos);
            }
          });
          if (porPersona.isNotEmpty) {
            tiempos[tiempo] = porPersona;
          }
        }
      });
    }

    // El gerundio viene al lado de "tiempos", no adentro, y es una sola forma
    // sin personas. Se lo suma como un tiempo más con una persona única, así
    // el sorteo, el quiz y las frases lo usan sin ningún caso especial.
    final gerundio = json['gerundio'];
    if (gerundio is Map<String, dynamic>) {
      final conjugacion = Conjugacion.desdeJson(gerundio);
      if (conjugacion.italiano.isNotEmpty) {
        tiempos[tiempoGerundio] = {personaGerundio: conjugacion};
      }
    }

    return Verbo(
      nombre: nombre,
      traduccion: json['traduccion'] as String? ?? nombre,
      tiempos: tiempos,
    );
  }
}

class DatosVerbos {
  const DatosVerbos({required this.version, required this.verbos});

  final int version;
  final Map<String, Verbo> verbos;

  factory DatosVerbos.desdeJson(Map<String, dynamic> json) {
    // Si no viene la clave "verbos", se toma el objeto entero como el mapa de
    // verbos: misma tolerancia que datos.get("verbos", datos) en Kivy.
    final crudos = json['verbos'] is Map<String, dynamic>
        ? json['verbos'] as Map<String, dynamic>
        : json;

    final verbos = <String, Verbo>{};
    crudos.forEach((nombre, datos) {
      if (datos is Map<String, dynamic>) {
        verbos[nombre] = Verbo.desdeJson(nombre, datos);
      }
    });

    return DatosVerbos(
      version: json['version'] as int? ?? 1,
      verbos: verbos,
    );
  }
}
