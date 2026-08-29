import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/constantes.dart';
import 'package:tukyliano/datos/almacenamiento_clave.dart';
import 'package:tukyliano/datos/repositorio_particelle.dart';
import 'package:tukyliano/main.dart';
import 'package:tukyliano/widgets/barra_superior.dart';

import 'util_pantalla.dart';

Future<void> _tocar(WidgetTester tester, String texto) async {
  // La barra se desliza, así que los últimos botones arrancan fuera de la
  // pantalla y hay que traerlos antes de tocarlos.
  final boton = find.widgetWithText(ElevatedButton, texto);
  await tester.scrollUntilVisible(
    boton,
    80,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

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

void main() {
  // En los tests no hay plugins de plataforma, así que la carga de verbos
  // (path_provider) falla y la sección Verbi queda sin datos. Acá se verifica
  // la navegación; el parseo se prueba en modelo_verbo_test.dart.
  testWidgets('la barra trae todas las secciones',
      (WidgetTester tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(const TukylianoApp());

    for (final seccion in Seccion.values) {
      expect(
        find.widgetWithText(ElevatedButton, seccion.etiqueta),
        findsOneWidget,
        reason: seccion.name,
      );
    }
  });

  testWidgets('arranca en Racconti, que es la primera de la barra',
      (WidgetTester tester) async {
    // Es lo que se hace cuando se agarra la app sin un plan: leer. Las otras
    // secciones piden elegir verbos y tiempos antes de empezar.
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(const TukylianoApp());
    await tester.pumpAndSettle();

    expect(Seccion.values.first, Seccion.racconti);
    // Ni la pantalla de Verbi ni la de Frasi, que son las que esperan verbos.
    expect(find.text('Cargando verbos...'), findsNothing);
  });

  testWidgets('la barra cambia de sección', (WidgetTester tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(const TukylianoApp());
    await tester.pumpAndSettle();

    // Articoli y Preposizioni no dependen de los verbos, así que entran
    // aunque estos no hayan cargado.
    await _tocar(tester, 'Articoli');
    expect(find.text('Cargando verbos...'), findsNothing);
    expect(find.text('Próximamente'), findsNothing);

    await _tocar(tester, 'Preposizioni');
    expect(find.text('Cargando verbos...'), findsNothing);
    expect(find.text('Próximamente'), findsNothing);

    await _tocar(tester, 'Verbi');
    expect(find.text('Cargando verbos...'), findsOneWidget);
  });

  testWidgets('Racconti entra a los cuentos, no al cartel',
      (WidgetTester tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(const TukylianoApp());
    await tester.pumpAndSettle();

    await _tocar(tester, 'Racconti');
    expect(find.text('Próximamente'), findsNothing);
    expect(find.text('Cargando verbos...'), findsNothing);
  });

  testWidgets('Leer, Ci y Ne ya tienen su botón, pero todavía no el contenido',
      (WidgetTester tester) async {
    // El botón se agregó antes que el contenido: hasta que estén las frases,
    // la sección tiene que decirlo en vez de mostrar una pantalla vacía.
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(const TukylianoApp());
    await tester.pumpAndSettle();

    for (final seccion in [Seccion.leer, Seccion.ci, Seccion.ne]) {
      await _tocar(tester, seccion.etiqueta);
      expect(find.text('Próximamente'), findsOneWidget, reason: seccion.name);
    }
  });

  testWidgets('Via entra a la práctica, con sus dos modos',
      (WidgetTester tester) async {
    usarPantallaDeCelular(tester);
    // Con el repositorio de verdad el asset no llega a leerse en un test de
    // widgets (no hay plataforma), así que se le pasa una frase a mano: lo que
    // se está probando es que la barra lleve al ejercicio y no al cartel.
    await tester.pumpWidget(TukylianoApp(via: _viaConUnaFrase()));
    await tester.pumpAndSettle();

    await _tocar(tester, 'Via');
    expect(find.text('Próximamente'), findsNothing);
    expect(find.text('Elegir'), findsOneWidget);
    expect(find.text('Escribir'), findsOneWidget);
  });

  testWidgets('Chat entra a la charla y pide la clave de la IA',
      (WidgetTester tester) async {
    usarPantallaDeCelular(tester);
    // Sin carpeta no hay clave guardada, que es lo que pasa la primera vez.
    await tester.pumpWidget(TukylianoApp(
      almacenClave: AlmacenamientoClave(carpeta: () async => null),
    ));
    await tester.pumpAndSettle();

    await _tocar(tester, 'Chat');
    expect(
      find.text('Necesitás una clave gratis de la IA (Gemini)'),
      findsOneWidget,
    );
  });
}
