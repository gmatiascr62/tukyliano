import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/datos/almacenamiento_clave.dart';
import 'package:tukyliano/datos/repositorio_frases.dart';
import 'package:tukyliano/datos/repositorio_verbos.dart';
import 'package:tukyliano/main.dart';
import 'package:tukyliano/modelos/verbo.dart';

import 'util_pantalla.dart';

/// Clave en memoria: en los tests no hay path_provider. La app ya no la usa,
/// pero la borra al arrancar, y eso tiene que seguir funcionando.
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

RepositorioFrases _frasesFalsas() => RepositorioFrases(
      leerAsset: (_) async => '''
        {"frases": [
          {"verbo": "avere", "tiempo": "presente", "persona": "io",
           "espanol": "Tengo mucha hambre", "italiano": "Ho molta fame",
           "pista": "hambre = fame"}
        ]}
      ''',
      cliente: MockClient((_) async => http.Response('', 404)),
      carpeta: () async => null,
    );

Widget _app({AlmacenamientoClave? clave}) => TukylianoApp(
      almacenClave: clave ?? _ClaveFalsa(),
      repositorio: _RepoFalso(),
      frasesLocales: _frasesFalsas(),
    );

Future<void> _tocar(WidgetTester tester, String texto) async {
  // La barra se desliza: si el botón quedó fuera de la pantalla hay que
  // traerlo antes de tocarlo.
  final boton = find.widgetWithText(ElevatedButton, texto);
  await tester.scrollUntilVisible(
    boton,
    80,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

/// Si la fila de selección está tildada.
bool _tildado(WidgetTester tester, String texto) {
  final fila = find.ancestor(of: find.text(texto), matching: find.byType(Row));
  final casilla = tester.widget<Checkbox>(
    find.descendant(of: fila.first, matching: find.byType(Checkbox)),
  );
  return casilla.value!;
}

void main() {
  testWidgets('Frasi lleva a elegir qué practicar, sin pedir ninguna clave',
      (tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _tocar(tester, 'Frasi');

    expect(find.text('Elegí los verbos a practicar'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Empezar'), findsOneWidget);
    // La pantalla de la clave de Gemini ya no existe.
    expect(find.widgetWithText(ElevatedButton, 'Pegar clave'), findsNothing);
  });

  testWidgets('volver a Frasi deja elegir de nuevo, no cae en la práctica',
      (tester) async {
    usarPantallaDeCelular(tester);
    // Regresión: antes conservaba el paso, así que al volver desde otra
    // sección entraba directo a practicar y no se podían cambiar los verbos.
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _tocar(tester, 'Frasi');
    await _tocar(tester, 'Empezar');
    expect(find.textContaining('Tengo mucha hambre'), findsOneWidget);

    await _tocar(tester, 'Verbi');
    await _tocar(tester, 'Frasi');

    expect(find.text('Elegí los verbos a practicar'), findsOneWidget);
    expect(find.textContaining('Tengo mucha hambre'), findsNothing);
  });

  testWidgets('al volver, los tildes quedan como se habían dejado',
      (tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // En Frasi se destilda essere y se practica.
    await _tocar(tester, 'Frasi');
    await tester.tap(find.text('essere (ser/estar)'));
    await tester.pump();
    await _tocar(tester, 'Empezar');

    // Se pasa por otra sección y se vuelve.
    await _tocar(tester, 'Verbi');
    await _tocar(tester, 'Frasi');

    expect(_tildado(tester, 'essere (ser/estar)'), isFalse);
    expect(_tildado(tester, 'avere (tener)'), isTrue);
  });

  testWidgets('cada sección recuerda su propia selección', (tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // En Frasi se destilda essere.
    await _tocar(tester, 'Frasi');
    await tester.tap(find.text('essere (ser/estar)'));
    await tester.pump();
    await _tocar(tester, 'Empezar');

    // Verbi no se contagia: sigue con todo tildado.
    await _tocar(tester, 'Verbi');
    expect(_tildado(tester, 'essere (ser/estar)'), isTrue);
  });

  testWidgets('no muestra nada sobre el chequeo de verbos nuevos',
      (tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _tocar(tester, 'Verbi');
    await _tocar(tester, 'Empezar');

    // El repositorio devuelve yaAlDia; antes eso se mostraba en pantalla.
    expect(find.textContaining('última versión'), findsNothing);
    expect(find.textContaining('Buscando verbos'), findsNothing);
  });

  testWidgets('borra la clave de Gemini que quedó guardada de antes',
      (tester) async {
    usarPantallaDeCelular(tester);
    final clave = _ClaveFalsa('CLAVE-VIEJA');

    await tester.pumpWidget(_app(clave: clave));
    await tester.pumpAndSettle();

    expect(clave.guardada, isNull);
  });
}
