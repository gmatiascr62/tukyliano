import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/constantes.dart';
import 'package:tukyliano/datos/progreso.dart';
import 'package:tukyliano/datos/repositorio_particelle.dart';
import 'package:tukyliano/main.dart';
import 'package:tukyliano/modelos/seccion.dart';
import 'package:tukyliano/pantallas/pantalla_gramatica.dart';
import 'package:tukyliano/modelos/destino.dart';

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
  await tester.pumpWidget(
    app ??
        TukylianoApp(progreso: _progresoDePrueba(), camino: caminoDePrueba()),
  );
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
  testWidgets('en el mapa están las cuatro herramientas, y solo esas cuatro', (
    WidgetTester tester,
  ) async {
    await _abrir(tester);

    // Son cuatro, no seis: gramática y hablar están adentro de la ciudad.
    // Esto lo marcó Matías mirando el APK, así que el test mira las dos
    // cosas —las que tienen que estar y las que no— y no solo las primeras:
    // si solo mirara las cuatro, volver a poner las seis pasaría en verde.
    for (final destino in herramientasDelMapa) {
      expect(
        find.byTooltip(destino.etiqueta),
        findsOneWidget,
        reason: destino.name,
      );
    }
    for (final destino in paraPracticarMas) {
      expect(
        find.byTooltip(destino.etiqueta),
        findsNothing,
        reason: destino.name,
      );
    }
    expect(
      herramientasDelMapa.length + paraPracticarMas.length,
      Destino.values.length,
      reason: 'ningún destino puede quedar sin pantalla de dónde salir',
    );

    // El inicio no es una sección: no hay de dónde volver.
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('el mapa muestra las seis luces y la palabra del color', (
    WidgetTester tester,
  ) async {
    // Antes abajo había una semana dibujada —siete marcas, una por día— y
    // el renglón "faltan 32". La semana contaba días; esto cuenta
    // lecciones, que es lo que de verdad hace avanzar. Lo pidió Matías
    // así: seis luces, dos rojas, dos amarillas y dos verdes.
    final progreso = _progresoDePrueba()
      ..termino('olbia-1')
      ..termino('olbia-2');
    await _abrir(
      tester,
      app: TukylianoApp(progreso: progreso, camino: caminoDePrueba()),
    );

    // Dos lecciones: una luz, y con una luz se está en rojo.
    expect(find.text('Cuidado'), findsOneWidget);
    expect(find.text('Vas bien'), findsNothing);

    // Las letras de los días se fueron, y el número también.
    expect(find.textContaining('faltan'), findsNothing);
    final iniciales = find
        .byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data ?? '').length == 1 &&
              'LMXJVSD'.contains(w.data!),
        )
        .evaluate();
    expect(iniciales, isEmpty, reason: 'sin letras de días');
  });

  testWidgets('con las seis luces prendidas el mapa dice que vas bien', (
    WidgetTester tester,
  ) async {
    final progreso = _progresoDePrueba();
    for (var i = 1; i <= 10; i++) {
      progreso.termino('olbia-$i');
    }
    for (var i = 1; i <= 2; i++) {
      progreso.termino('cagliari-$i');
    }
    await _abrir(
      tester,
      app: TukylianoApp(progreso: progreso, camino: caminoDePrueba()),
    );

    expect(find.text('Vas bien'), findsOneWidget);
    expect(find.text('Cuidado'), findsNothing);
  });

  testWidgets('tocar al perrito abre el álbum del viaje, y la flecha vuelve', (
    WidgetTester tester,
  ) async {
    // El perrito no es un adorno: es la puerta del álbum. Y la puerta se
    // prueba desde la app entera, no desde el mapa suelto, porque lo que
    // se rompe fácil es el cableado —quién abre qué y adónde vuelve—.
    await _abrir(tester);

    await tester.tap(find.byTooltip('El álbum del viaje'));
    await tester.pumpAndSettle();
    expect(find.text('El álbum del viaje'), findsWidgets);

    // De cero no hay ninguna abierta, pero el álbum se ve igual: las
    // tapadas dicen cuánto falta.
    expect(find.text('0 de 15 fotos'), findsOneWidget);
    // Una por ciudad con álbum: la primera foto de cada una se abre a
    // las dos lecciones de esa ciudad.
    expect(find.text('Faltan 2 lecciones'), findsWidgets);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text(primeraCiudad), findsOneWidget);
  });

  testWidgets('con dos lecciones hechas el álbum tiene su primera foto', (
    WidgetTester tester,
  ) async {
    final progreso = _progresoDePrueba()
      ..termino('olbia-1')
      ..termino('olbia-2');
    await _abrir(
      tester,
      app: TukylianoApp(progreso: progreso, camino: caminoDePrueba()),
    );

    await tester.tap(find.byTooltip('El álbum del viaje'));
    await tester.pumpAndSettle();

    expect(find.text('1 de 15 fotos'), findsOneWidget);
    expect(find.text('Selfie en la playa de Pittulongu'), findsOneWidget);
  });

  testWidgets('entrar a una sección y volver al inicio con la flecha', (
    WidgetTester tester,
  ) async {
    await _abrir(tester);

    await entrarA(tester, Destino.racconti);
    expect(find.text('Racconti'), findsWidgets);

    await _volver(tester);
    expect(find.text('Palermo'), findsOneWidget);
  });

  testWidgets('gramática abre los siete temas', (WidgetTester tester) async {
    await _abrir(tester);
    await entrarA(tester, Destino.gramatica);

    for (final (seccion, _, _) in PantallaGramatica.temas) {
      expect(find.text(seccion.etiqueta), findsOneWidget, reason: seccion.name);
    }
  });

  testWidgets('desde un tema se vuelve a la lista de temas, no al inicio', (
    WidgetTester tester,
  ) async {
    await _abrir(tester);
    await entrarA(tester, Destino.gramatica);

    await tester.tap(find.text('Articoli'));
    await tester.pumpAndSettle();
    expect(find.text('Cargando verbos...'), findsNothing);

    await _volver(tester);
    // La lista de temas, no el inicio.
    expect(find.text('Preposizioni'), findsOneWidget);
    expect(find.text('Palermo'), findsNothing);

    await _volver(tester);
    expect(find.text('Palermo'), findsOneWidget);
  });

  testWidgets('Ci y Ne ya tienen su lugar, pero todavía no el contenido', (
    WidgetTester tester,
  ) async {
    await _abrir(tester);
    await entrarA(tester, Destino.gramatica);

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
        camino: caminoDePrueba(),
        voz: VozFalsa(),
        escucha: EscuchaFalsa(),
        progreso: _progresoDePrueba(),
      ),
    );

    await entrarA(tester, Destino.hablar);
    expect(find.text('DECILA EN VOZ ALTA'), findsOneWidget);
  });

  testWidgets('Via entra a la práctica, con sus dos modos', (
    WidgetTester tester,
  ) async {
    await _abrir(
      tester,
      app: TukylianoApp(
        via: _viaConUnaFrase(),
        progreso: _progresoDePrueba(),
        camino: caminoDePrueba(),
      ),
    );

    await entrarA(tester, Destino.gramatica);
    await tester.tap(find.text('Via'));
    await tester.pumpAndSettle();

    expect(find.text('Próximamente'), findsNothing);
    expect(find.text('Elegir'), findsOneWidget);
    expect(find.text('Escribir'), findsOneWidget);
  });

  testWidgets('Chat abre en la charla guionada y no pide ninguna clave', (
    WidgetTester tester,
  ) async {
    await _abrir(
      tester,
      app: TukylianoApp(
        progreso: _progresoDePrueba(),
        camino: caminoDePrueba(),
      ),
    );

    await entrarA(tester, Destino.chat);

    // La charla del bar anda sin internet y sin clave.
    expect(find.text('Al bar'), findsOneWidget);

    // Y la libre tampoco pide clave: habla con el servidor propio, que es el
    // que tiene el modelo del otro lado. La pantalla que pedía pegar una
    // clave de Google ya no existe.
    await tester.tap(find.text('Libre'));
    await tester.pumpAndSettle();
    expect(find.textContaining('clave'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('del mapa a una lección: Olbia, Empezar, y la primera regla', (
    WidgetTester tester,
  ) async {
    // El camino entero, de punta a punta, en la app de verdad: es lo que
    // hace alguien que abre la app por primera vez.
    await _abrir(tester);

    await tester.tap(find.text(primeraCiudad));
    await tester.pumpAndSettle();
    expect(find.text('Cómo suena el italiano'), findsOneWidget);

    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();

    // Arranca explicando, no preguntando: es lo que la hacía imposible
    // para el que no sabe nada.
    expect(find.text('Las vocales son las mismas'), findsOneWidget);

    // Y la cruz devuelve a la ciudad, sin darla por hecha.
    await tester.tap(find.byTooltip('Salir'));
    await tester.pumpAndSettle();
    expect(find.text('Empezar'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
  });

  testWidgets('con las lecciones hechas, Empezar abre la prueba de la ciudad', (
    WidgetTester tester,
  ) async {
    final progreso = _progresoDePrueba();
    for (var i = 1; i <= 10; i++) {
      progreso.termino('olbia-$i');
    }
    await _abrir(
      tester,
      app: TukylianoApp(progreso: progreso, camino: caminoDePrueba()),
    );

    await tester.tap(find.text(primeraCiudad));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Empezar'), 150);
    await tester.ensureVisible(find.text('Empezar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();

    // Pregunta de entrada: la prueba no enseña nada, toma.
    expect(find.text('Comprobar'), findsOneWidget);
    expect(find.text('Palabra nueva'), findsNothing);
    expect(find.text('Terminar'), findsNothing);

    // Y se sale sin darla por hecha.
    await tester.tap(find.byTooltip('Salir'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('La prueba de Olbia'), 150);
    expect(find.text('La prueba de Olbia'), findsOneWidget);
    expect(progreso.hizo('olbia-prueba'), isFalse);
  });
}
