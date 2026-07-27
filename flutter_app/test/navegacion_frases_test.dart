import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/datos/almacenamiento_clave.dart';
import 'package:tukyliano/datos/repositorio_frases.dart';
import 'package:tukyliano/datos/repositorio_verbos.dart';
import 'package:tukyliano/ia/gemini.dart';
import 'package:tukyliano/main.dart';
import 'package:tukyliano/modelos/verbo.dart';

import 'util_pantalla.dart';

/// Clave en memoria: en los tests no hay path_provider.
class _ClaveFalsa extends AlmacenamientoClave {
  _ClaveFalsa([this.guardada]);

  String? guardada;

  @override
  Future<String?> cargar() async => guardada;

  @override
  Future<void> guardar(String clave) async => guardada = clave;

  @override
  Future<void> borrar() async => guardada = null;
}

/// Verbos en memoria, por el mismo motivo.
class _RepoFalso extends RepositorioVerbos {
  static final _datos = DatosVerbos.desdeJson(jsonDecode('''
    {"version": 5, "verbos": {
      "essere": {"traduccion": "ser/estar", "tiempos": {
        "presente": {"io": {"italiano": "sono", "espanol": "yo soy/estoy"}}
      }},
      "avere": {"traduccion": "tener", "tiempos": {
        "presente": {"io": {"italiano": "ho", "espanol": "yo tengo"}}
      }}
    }}
  ''') as Map<String, dynamic>);

  @override
  Future<DatosVerbos> cargar() async => _datos;

  @override
  Future<ResultadoActualizacion> verificarActualizacion(int version) async =>
      const ResultadoActualizacion(EstadoActualizacion.yaAlDia);
}

Gemini _geminiFalso() => Gemini(
      cliente: MockClient((_) async => http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'text':
                            '{"espanol": "Hoy soy feliz", "italiano": "Oggi sono felice"}'
                      }
                    ]
                  }
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )),
    );

Future<void> _tocar(WidgetTester tester, String texto) async {
  await tester.tap(find.widgetWithText(ElevatedButton, texto));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('con clave guardada, Frases lleva a elegir qué practicar',
      (tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(TukylianoApp(
      almacenClave: _ClaveFalsa('FAKE'),
      gemini: _geminiFalso(),
      repositorio: _RepoFalso(),
      // Vacío a propósito: estos tests miran la navegación, así que la frase
      // tiene que venir de la IA simulada y no del asset real.
      frasesLocales: RepositorioFrases(leerAsset: (_) async => '{"frases": []}'),
    ));
    await tester.pumpAndSettle();

    await _tocar(tester, 'Frases');

    expect(find.text('Elegí los verbos a practicar'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Empezar'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Pegar clave'), findsNothing);
  });

  testWidgets('volver a Frases deja elegir de nuevo, no cae en la práctica',
      (tester) async {
    usarPantallaDeCelular(tester);
    // Regresión: antes conservaba el paso, así que al volver desde otra
    // sección entraba directo a practicar y no se podían cambiar los verbos.
    await tester.pumpWidget(TukylianoApp(
      almacenClave: _ClaveFalsa('FAKE'),
      gemini: _geminiFalso(),
      repositorio: _RepoFalso(),
      // Vacío a propósito: estos tests miran la navegación, así que la frase
      // tiene que venir de la IA simulada y no del asset real.
      frasesLocales: RepositorioFrases(leerAsset: (_) async => '{"frases": []}'),
    ));
    await tester.pumpAndSettle();

    await _tocar(tester, 'Frases');
    await _tocar(tester, 'Empezar');
    expect(find.textContaining('Hoy soy feliz'), findsOneWidget);

    await _tocar(tester, 'Verbos');
    await _tocar(tester, 'Frases');

    expect(find.text('Elegí los verbos a practicar'), findsOneWidget);
    expect(find.textContaining('Hoy soy feliz'), findsNothing);
  });

  testWidgets('sin clave guardada, Frases la pide y después deja elegir',
      (tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(TukylianoApp(
      almacenClave: _ClaveFalsa(),
      gemini: _geminiFalso(),
      repositorio: _RepoFalso(),
      // Vacío a propósito: estos tests miran la navegación, así que la frase
      // tiene que venir de la IA simulada y no del asset real.
      frasesLocales: RepositorioFrases(leerAsset: (_) async => '{"frases": []}'),
    ));
    await tester.pumpAndSettle();

    await _tocar(tester, 'Frases');
    expect(find.widgetWithText(ElevatedButton, 'Pegar clave'), findsOneWidget);

    // Sin nada en el portapapeles, Guardar avisa en vez de seguir.
    await _tocar(tester, 'Guardar');
    expect(find.textContaining('antes de guardar'), findsOneWidget);
  });
}
