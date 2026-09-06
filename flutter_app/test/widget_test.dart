import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/constantes.dart';
import 'package:tukyliano/datos/almacenamiento_clave.dart';
import 'package:tukyliano/datos/progreso.dart';
import 'package:tukyliano/datos/repositorio_particelle.dart';
import 'package:tukyliano/main.dart';
import 'package:tukyliano/modelos/seccion.dart';
import 'package:tukyliano/pantallas/pantalla_gramatica.dart';
import 'package:tukyliano/pantallas/pantalla_inicio.dart';

import 'escucha_falsa.dart';
import 'util_pantalla.dart';
import 'voz_falsa.dart';

/// Sin carpeta el progreso no se escribe en ningún lado: vale solo para el
/// test que lo está corriendo.
Progreso _progresoDePrueba() => Progreso(carpeta: () async => null);

RepositorioParticelle _viaConUnaFrase() => RepositorioParticelle(
      asset: assetVia,
      urlRemoto: urlViaRemoto,
      archivoLocal: archivoViaLocal,
      leerAsset: (_) async => '''
        {"version": 1, "frases": [
          {"frase": "___ via, è tardi.", "correcta": "Vado", "es": "me voy",
           "opciones": ["Vado", "Porto", "Butto", "Mando"],
           "explicacion": "andare via = irse.", "persona": "io"}
        ]}
      ''',
      cliente: MockClient((_) async => http.Response('', 404)),
      carpeta: () async => null,
    );

Future<void> _abrir(WidgetTester tester, {Widget? app}) async {
  usarPantallaDeCelular(tester);
  await tester.pumpWidget(app ?? TukylianoApp(progreso: _progresoDePrueba()));
  await tester.pumpAndSettle();
}

/// Toca uno de los cuatro botones redondos del inicio.
Future<void> _entrarA(WidgetTester tester, Destino destino) async {
  await tester.tap(find.byIcon(destino.icono));
  await tester.pumpAndSettle();
}

Future<void> _volver(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.arrow_back));
  await tester.pumpAndSettle();
}

void main() {
  // En los tests no hay plugins de plataforma, así que la carga de verbos
  // (path_provider) falla y la sección Verbi queda sin datos. Acá se verifica
  // la navegación; el parseo se prueba en modelo_verbo_test.dart.
  testWidgets('arranca en el inicio, con los cuatro botones',
      (WidgetTester tester) async {
    await _abrir(tester);

    for (final destino in Destino.values) {
      expect(find.text(destino.etiqueta), findsOneWidget, reason: destino.name);
    }
    // El inicio no es una sección: no hay de dónde volver.
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('el inicio muestra el nivel', (WidgetTester tester) async {
    await _abrir(tester);

    expect(find.text('NIVEL 1'), findsOneWidget);
    expect(find.text('Principiante'), findsOneWidget);
  });

  testWidgets('entrar a una sección y volver al inicio con la flecha',
      (WidgetTester tester) async {
    await _abrir(tester);

    await _entrarA(tester, Destino.racconti);
    expect(find.text('Racconti'), findsWidgets);

    await _volver(tester);
    expect(find.text('Principiante'), findsOneWidget);
  });

  testWidgets('gramática abre los siete temas', (WidgetTester tester) async {
    await _abrir(tester);
    await _entrarA(tester, Destino.gramatica);

    for (final (seccion, _, _) in PantallaGramatica.temas) {
      expect(find.text(seccion.etiqueta), findsOneWidget, reason: seccion.name);
    }
  });

  testWidgets('desde un tema se vuelve a la lista de temas, no al inicio',
      (WidgetTester tester) async {
    await _abrir(tester);
    await _entrarA(tester, Destino.gramatica);

    await tester.tap(find.text('Articoli'));
    await tester.pumpAndSettle();
    expect(find.text('Cargando verbos...'), findsNothing);

    await _volver(tester);
    // La lista de temas, no el inicio.
    expect(find.text('Preposizioni'), findsOneWidget);
    expect(find.text('Principiante'), findsNothing);

    await _volver(tester);
    expect(find.text('Principiante'), findsOneWidget);
  });

  testWidgets('Ci y Ne ya tienen su lugar, pero todavía no el contenido',
      (WidgetTester tester) async {
    await _abrir(tester);
    await _entrarA(tester, Destino.gramatica);

    for (final seccion in [Seccion.ci, Seccion.ne]) {
      await tester.tap(find.text(seccion.etiqueta));
      await tester.pumpAndSettle();
      expect(find.text('Próximamente'), findsOneWidget, reason: seccion.name);
      await _volver(tester);
    }
  });

  testWidgets('Parlare entra a la pronunciación', (WidgetTester tester) async {
    // Con el micrófono de verdad no hay plugin en un test, así que se le pasa
    // uno de mentira: lo que se prueba es que el botón lleve al ejercicio.
    await _abrir(
      tester,
      app: TukylianoApp(
        voz: VozFalsa(),
        escucha: EscuchaFalsa(),
        progreso: _progresoDePrueba(),
      ),
    );

    await _entrarA(tester, Destino.hablar);
    expect(find.text('DECILA EN VOZ ALTA'), findsOneWidget);
  });

  testWidgets('Via entra a la práctica, con sus dos modos',
      (WidgetTester tester) async {
    await _abrir(
      tester,
      app: TukylianoApp(via: _viaConUnaFrase(), progreso: _progresoDePrueba()),
    );

    await _entrarA(tester, Destino.gramatica);
    await tester.tap(find.text('Via'));
    await tester.pumpAndSettle();

    expect(find.text('Próximamente'), findsNothing);
    expect(find.text('Elegir'), findsOneWidget);
    expect(find.text('Escribir'), findsOneWidget);
  });

  testWidgets('Chat entra a la charla y pide la clave de la IA',
      (WidgetTester tester) async {
    // Sin carpeta no hay clave guardada, que es lo que pasa la primera vez.
    await _abrir(
      tester,
      app: TukylianoApp(
        almacenClave: AlmacenamientoClave(carpeta: () async => null),
        progreso: _progresoDePrueba(),
      ),
    );

    await _entrarA(tester, Destino.chat);
    expect(
      find.text('Necesitás una clave gratis de la IA (Gemini)'),
      findsOneWidget,
    );
  });
}
