import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/datos/repositorio_racconti.dart';
import 'package:tukyliano/datos/voz.dart';
import 'package:tukyliano/pantallas/pantalla_racconti.dart';
import 'package:tukyliano/tema.dart';
import 'package:tukyliano/widgets/portada_racconto.dart';

import 'util_pantalla.dart';
import 'voz_falsa.dart';

const _dos = '''
  {
    "version": 1,
    "racconti": [
      {
        "id": "la-colazione", "titulo": "La colazione",
        "titulo_es": "El desayuno", "nivel": 1,
        "vocabulario": [{"it": "presto", "es": "temprano"}],
        "lineas": [
          {"it": "Marco è in cucina.", "es": "Marco está en la cocina."},
          {"it": "È mattina presto.", "es": "Es temprano a la mañana."},
          {"it": "Marco ha fame.", "es": "Marco tiene hambre."}
        ]
      },
      {
        "id": "il-lavoro", "titulo": "Il lavoro", "titulo_es": "El trabajo",
        "nivel": 3,
        "vocabulario": [],
        "lineas": [{"it": "Marco lavora.", "es": "Marco trabaja."}]
      }
    ]
  }
''';

/// Un cuento suelto y una novela de dos capítulos.
const _conNovela = '''
  {
    "version": 1,
    "racconti": [
      {
        "id": "la-colazione", "titulo": "La colazione",
        "titulo_es": "El desayuno", "nivel": 1, "imagen": "colazione",
        "foto": "gatto",
        "vocabulario": [],
        "lineas": [
          {"it": "Marco ha fame.", "es": "Marco tiene hambre."},
          {"it": "Beve il latte.", "es": "Toma la leche.", "cuadro": 2}
        ]
      },
      {
        "id": "saga-01", "titulo": "Capitolo 1 · Il testamento",
        "titulo_es": "Capítulo 1 · El testamento", "nivel": 6,
        "imagen": "mistero",
        "serie": "la-saga", "serie_titulo": "Il segreto dei Ferrante",
        "serie_titulo_es": "El secreto de los Ferrante",
        "vocabulario": [],
        "lineas": [
          {"it": "Il vecchio è morto.", "es": "El viejo murió."},
          {"it": "Nessuno piange.", "es": "Nadie llora."}
        ]
      },
      {
        "id": "saga-02", "titulo": "Capitolo 2 · L'arrivo",
        "titulo_es": "Capítulo 2 · La llegada", "nivel": 6,
        "serie": "la-saga", "serie_titulo": "Il segreto dei Ferrante",
        "serie_titulo_es": "El secreto de los Ferrante",
        "vocabulario": [],
        "lineas": [{"it": "Lei arriva.", "es": "Ella llega."}]
      }
    ]
  }
''';

RepositorioRacconti _repo(String json) => RepositorioRacconti(
      leerAsset: (_) async => json,
      cliente: MockClient((_) async => http.Response('', 404)),
      carpeta: () async => null,
    );

Future<void> _abrir(WidgetTester tester, String json, {Voz? voz}) async {
  usarPantallaDeCelular(tester);
  await tester.pumpWidget(MaterialApp(
    theme: Tema.datos,
    home: Scaffold(
      body: PantallaRacconti(
        repositorio: _repo(json),
        voz: voz ?? VozFalsa(),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Los nombres de las fotos que se están mostrando. PortadaRacconto también
/// usa FotoRacconto (con el nombre vacío) para poder caer en el dibujo, así
/// que se filtran las vacías.
List<String> _fotos(WidgetTester tester) => tester
    .widgetList<FotoRacconto>(find.byType(FotoRacconto))
    .map((f) => f.nombre)
    .where((n) => n.isNotEmpty)
    .toList();

Future<void> _tocar(WidgetTester tester, String texto) async {
  await tester.tap(find.text(texto));
  await tester.pumpAndSettle();
}

void main() {
  group('la lista', () {
    testWidgets('muestra los cuentos con su título en los dos idiomas',
        (tester) async {
      await _abrir(tester, _dos);

      expect(find.text('La colazione'), findsOneWidget);
      expect(find.text('El desayuno'), findsOneWidget);
      expect(find.text('Il lavoro'), findsOneWidget);
    });

    testWidgets('muestra el nivel y cuántas frases tiene', (tester) async {
      await _abrir(tester, _dos);

      expect(find.text('Nivel 1'), findsOneWidget);
      expect(find.text('3 frases'), findsOneWidget);
    });

    testWidgets('sin cuentos cargados lo avisa', (tester) async {
      await _abrir(tester, '{"version": 1, "racconti": []}');

      expect(find.textContaining('Todavía no hay cuentos'), findsOneWidget);
    });

    testWidgets('un JSON roto no rompe la pantalla', (tester) async {
      await _abrir(tester, 'esto no es JSON');

      expect(find.textContaining('Todavía no hay cuentos'), findsOneWidget);
    });

    testWidgets('cada cuento muestra su portada', (tester) async {
      await _abrir(tester, _dos);

      final dibujos = tester
          .widgetList<PortadaRacconto>(find.byType(PortadaRacconto))
          .map((p) => portadaDe(p.imagen).dibujo)
          .toList();

      expect(dibujos.length, 2);
    });

    testWidgets('la obra sin fotos usa el dibujo del primer capítulo',
        (tester) async {
      await _abrir(tester, _conNovela);

      final dibujos = tester
          .widgetList<PortadaRacconto>(find.byType(PortadaRacconto))
          .map((p) => portadaDe(p.imagen).dibujo)
          .toList();

      // Solo la novela: el cuento con tapa ilustrada no dibuja nada.
      expect(dibujos, [Dibujo.villa]);
    });

    testWidgets('el cuento sin portada declarada se ve igual', (tester) async {
      await _abrir(tester, _dos);

      expect(find.byType(PortadaRacconto), findsNWidgets(2));
      expect(find.text('La colazione'), findsOneWidget);
    });
  });

  group('las fotos', () {
    testWidgets('en la lista se ve la tapa grande, sola', (tester) async {
      // La tapa ya trae adentro el título, el nivel y cuántas frases son:
      // ponerlos al lado sería decir dos veces lo mismo.
      await _abrir(tester, _conNovela);

      expect(_fotos(tester), ['gatto-portada']);
      expect(find.text('La colazione'), findsNothing);
      expect(find.text('El desayuno'), findsNothing);
    });

    testWidgets('adentro del cuento la tapa ya no aparece', (tester) async {
      await _abrir(tester, _conNovela);
      // Se entra tocando la tapa: en la lista no hay texto de ese cuento.
      await tester.tap(find.byType(FotoRacconto).first);
      await tester.pumpAndSettle();

      final fotos = tester
          .widgetList<FotoDelCuento>(find.byType(FotoDelCuento))
          .map((f) => f.nombre)
          .toList();

      // Solo el cuadro de la segunda frase: la tapa quedó en la lista.
      expect(fotos, ['gatto-2']);
      expect(find.text('Marco ha fame.'), findsOneWidget);
    });

    testWidgets('el cuadro va en la frase que ilustra', (tester) async {
      await _abrir(tester, _conNovela);
      await tester.tap(find.byType(FotoRacconto).first);
      await tester.pumpAndSettle();

      final linea = find.ancestor(
        of: find.text('Beve il latte.'),
        matching: find.byType(Column),
      );
      expect(
        find.descendant(of: linea.first, matching: find.byType(FotoDelCuento)),
        findsOneWidget,
      );
      // La primera frase no tiene cuadro, así que no le aparece ninguno.
      expect(find.byType(FotoDelCuento), findsOneWidget);
    });

    testWidgets('un cuento sin fotos se sigue viendo con el dibujo',
        (tester) async {
      await _abrir(tester, _dos);
      await _tocar(tester, 'La colazione');

      expect(find.byType(FotoDelCuento), findsNothing);
      expect(find.byType(PortadaRacconto), findsOneWidget);
    });
  });

  group('la novela en la lista', () {
    testWidgets('ocupa un renglón solo, no uno por capítulo', (tester) async {
      await _abrir(tester, _conNovela);

      expect(find.text('Il segreto dei Ferrante'), findsOneWidget);
      expect(find.text('El secreto de los Ferrante'), findsOneWidget);
      // Los capítulos están adentro, no en la lista.
      expect(find.textContaining('Capitolo 1'), findsNothing);
      expect(find.textContaining('Capitolo 2'), findsNothing);
    });

    testWidgets('dice cuántos capítulos tiene, no cuántas frases',
        (tester) async {
      await _abrir(tester, _conNovela);

      expect(find.text('2 capítulos'), findsOneWidget);
    });

    testWidgets('la presentación de la obra lleva su dibujo', (tester) async {
      await _abrir(tester, _conNovela);
      await _tocar(tester, 'Il segreto dei Ferrante');

      final banda = tester.widget<BandaPortada>(find.byType(BandaPortada));
      expect(banda.imagen, 'mistero');
      expect(banda.titulo, 'Il segreto dei Ferrante');
    });

    testWidgets('tocarla lleva a elegir el capítulo', (tester) async {
      await _abrir(tester, _conNovela);
      await _tocar(tester, 'Il segreto dei Ferrante');

      expect(find.text('Capitolo 1 · Il testamento'), findsOneWidget);
      expect(find.text("Capitolo 2 · L'arrivo"), findsOneWidget);
      // Todavía no se está leyendo nada.
      expect(find.text('Il vecchio è morto.'), findsNothing);
    });

    testWidgets('el capítulo elegido se abre para leer', (tester) async {
      await _abrir(tester, _conNovela);
      await _tocar(tester, 'Il segreto dei Ferrante');
      await _tocar(tester, 'Capitolo 1 · Il testamento');

      expect(find.text('Il vecchio è morto.'), findsOneWidget);
      expect(find.text('Nessuno piange.'), findsOneWidget);
      expect(find.text("Capitolo 2 · L'arrivo"), findsNothing);
    });

    testWidgets('volver desde el capítulo lleva a los capítulos, no a la lista',
        (tester) async {
      await _abrir(tester, _conNovela);
      await _tocar(tester, 'Il segreto dei Ferrante');
      await _tocar(tester, 'Capitolo 1 · Il testamento');
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text("Capitolo 2 · L'arrivo"), findsOneWidget);
      expect(find.text('La colazione'), findsNothing);
    });

    testWidgets('volver otra vez sí lleva a la lista de cuentos',
        (tester) async {
      await _abrir(tester, _conNovela);
      await _tocar(tester, 'Il segreto dei Ferrante');
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // La tapa ilustrada del otro cuento vuelve a estar.
      expect(_fotos(tester), ['gatto-portada']);
      expect(find.text('Il segreto dei Ferrante'), findsOneWidget);
    });

    testWidgets('un cuento suelto se abre derecho, sin pasar por capítulos',
        (tester) async {
      await _abrir(tester, _conNovela);
      await tester.tap(find.byType(FotoRacconto).first);
      await tester.pumpAndSettle();

      expect(find.text('Marco ha fame.'), findsOneWidget);
    });
  });

  group('el cuento abierto', () {
    testWidgets('muestra los renglones en italiano, sin traducción',
        (tester) async {
      await _abrir(tester, _dos);
      await _tocar(tester, 'La colazione');

      expect(find.text('Marco è in cucina.'), findsOneWidget);
      expect(find.text('Marco está en la cocina.'), findsNothing);
      // El otro cuento ya no está.
      expect(find.text('Il lavoro'), findsNothing);
    });

    testWidgets('tocar un renglón revela su traducción', (tester) async {
      await _abrir(tester, _dos);
      await _tocar(tester, 'La colazione');
      await _tocar(tester, 'Marco è in cucina.');

      expect(find.text('Marco está en la cocina.'), findsOneWidget);
      // Solo la del renglón tocado.
      expect(find.text('Marco tiene hambre.'), findsNothing);
    });

    testWidgets('tocarlo de nuevo la esconde', (tester) async {
      await _abrir(tester, _dos);
      await _tocar(tester, 'La colazione');
      await _tocar(tester, 'Marco è in cucina.');
      await _tocar(tester, 'Marco è in cucina.');

      expect(find.text('Marco está en la cocina.'), findsNothing);
    });

    testWidgets('Mostrar todo revela todos y después los esconde',
        (tester) async {
      await _abrir(tester, _dos);
      await _tocar(tester, 'La colazione');

      await _tocar(tester, 'Mostrar todo');
      expect(find.text('Marco está en la cocina.'), findsOneWidget);
      expect(find.text('Marco tiene hambre.'), findsOneWidget);

      await _tocar(tester, 'Ocultar todo');
      expect(find.text('Marco está en la cocina.'), findsNothing);
    });

    testWidgets('el vocabulario arranca plegado y se abre al tocarlo',
        (tester) async {
      await _abrir(tester, _dos);
      await _tocar(tester, 'La colazione');

      expect(find.text('Vocabulario (1)'), findsOneWidget);
      expect(find.text('temprano'), findsNothing);

      await _tocar(tester, 'Vocabulario (1)');
      expect(find.text('presto'), findsOneWidget);
      expect(find.text('temprano'), findsOneWidget);
    });

    testWidgets('un cuento sin vocabulario no muestra la sección',
        (tester) async {
      await _abrir(tester, _dos);
      await _tocar(tester, 'Il lavoro');

      expect(find.textContaining('Vocabulario'), findsNothing);
    });

    testWidgets('la flecha vuelve a la lista', (tester) async {
      await _abrir(tester, _dos);
      await _tocar(tester, 'La colazione');

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Il lavoro'), findsOneWidget);
      expect(find.text('Marco è in cucina.'), findsNothing);
    });

    testWidgets('al reabrirlo los renglones vuelven a estar tapados',
        (tester) async {
      await _abrir(tester, _dos);
      await _tocar(tester, 'La colazione');
      await _tocar(tester, 'Marco è in cucina.');

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await _tocar(tester, 'La colazione');

      expect(find.text('Marco está en la cocina.'), findsNothing);
    });
  });

  group('el audio', () {
    testWidgets('tocar un renglón lo pronuncia en italiano', (tester) async {
      final voz = VozFalsa();
      await _abrir(tester, _dos, voz: voz);
      await _tocar(tester, 'La colazione');

      await _tocar(tester, 'Marco è in cucina.');

      expect(voz.dicho, ['Marco è in cucina.']);
    });

    testWidgets('dice el italiano, nunca la traducción', (tester) async {
      // Escuchar el español no enseña nada y además taparía el italiano.
      final voz = VozFalsa();
      await _abrir(tester, _dos, voz: voz);
      await _tocar(tester, 'La colazione');

      await _tocar(tester, 'Marco è in cucina.');

      expect(voz.dicho.single, isNot(contains('cocina')));
    });

    testWidgets('esconder un renglón calla en vez de repetirlo',
        (tester) async {
      // Si hablara al esconderlo no habría forma de tapar la traducción sin
      // escuchar la frase otra vez.
      final voz = VozFalsa();
      await _abrir(tester, _dos, voz: voz);
      await _tocar(tester, 'La colazione');

      await _tocar(tester, 'Marco è in cucina.');
      await _tocar(tester, 'Marco è in cucina.');

      expect(voz.dicho.length, 1);
      expect(voz.callados, greaterThan(0));
    });

    testWidgets('el altavoz repite el renglón sin taparlo', (tester) async {
      final voz = VozFalsa();
      await _abrir(tester, _dos, voz: voz);
      await _tocar(tester, 'La colazione');
      await _tocar(tester, 'Marco è in cucina.');

      await tester.tap(find.byIcon(Icons.volume_up_outlined));
      await tester.pumpAndSettle();

      expect(voz.dicho, ['Marco è in cucina.', 'Marco è in cucina.']);
      // Y sigue revelado.
      expect(find.text('Marco está en la cocina.'), findsOneWidget);
    });

    testWidgets('el altavoz aparece solo en los renglones revelados',
        (tester) async {
      await _abrir(tester, _dos);
      await _tocar(tester, 'La colazione');

      expect(find.byIcon(Icons.volume_up_outlined), findsNothing);

      await _tocar(tester, 'Marco è in cucina.');
      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    });

    testWidgets('el botón de lento cambia la velocidad y vuelve',
        (tester) async {
      final voz = VozFalsa();
      await _abrir(tester, _dos, voz: voz);
      await _tocar(tester, 'La colazione');

      expect(voz.lenta, isNull);

      await _tocar(tester, 'Lento');
      expect(voz.lenta, isTrue);

      await _tocar(tester, 'Lento');
      expect(voz.lenta, isFalse);
    });

    testWidgets('se puede elegir entre las voces del celular', (tester) async {
      final voz = VozFalsa();
      await _abrir(tester, _dos, voz: voz);
      await _tocar(tester, 'La colazione');

      // La pastilla muestra la voz en uso, con nombre de persona.
      expect(find.text('Giulia'), findsOneWidget);

      await _tocar(tester, 'Giulia');
      await _tocar(tester, 'Lorenzo');

      expect(voz.vozElegida?.nombre, 'Lorenzo');
      expect(find.text('Lorenzo'), findsOneWidget);
      expect(find.text('Giulia'), findsNothing);
    });

    testWidgets('al elegir una voz la hace hablar para escucharla',
        (tester) async {
      // Sin esto habría que buscar un renglón para saber cómo suena.
      final voz = VozFalsa();
      await _abrir(tester, _dos, voz: voz);
      await _tocar(tester, 'La colazione');

      await _tocar(tester, 'Giulia');
      await _tocar(tester, 'Lorenzo');

      expect(voz.dicho, ['Lorenzo']);
    });

    testWidgets('con una sola voz instalada no hay nada que elegir',
        (tester) async {
      final voz = VozFalsa(cuantasVoces: 1);
      await _abrir(tester, _dos, voz: voz);
      await _tocar(tester, 'La colazione');

      expect(find.text('Giulia'), findsNothing);
      // La velocidad sí sigue estando.
      expect(find.text('Lento'), findsOneWidget);
    });

    testWidgets('salir del cuento corta lo que se esté diciendo',
        (tester) async {
      final voz = VozFalsa();
      await _abrir(tester, _dos, voz: voz);
      await _tocar(tester, 'La colazione');
      await _tocar(tester, 'Marco è in cucina.');

      final antes = voz.callados;
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(voz.callados, greaterThan(antes));
    });
  });

  group('sin la voz italiana instalada', () {
    testWidgets('no habla, porque lo leería con los sonidos de otro idioma',
        (tester) async {
      // La voz falsa tira si le piden hablar sin italiano: si la pantalla lo
      // intentara, este test explota en vez de pasar por casualidad.
      final voz = VozFalsa(hayItaliano: false);
      await _abrir(tester, _dos, voz: voz);
      await _tocar(tester, 'La colazione');

      await _tocar(tester, 'Marco è in cucina.');

      expect(voz.dicho, isEmpty);
      // Pero la traducción se revela igual: leer sigue funcionando.
      expect(find.text('Marco está en la cocina.'), findsOneWidget);
    });

    testWidgets('avisa cómo instalarla en vez de callarse la boca',
        (tester) async {
      final voz = VozFalsa(hayItaliano: false);
      await _abrir(tester, _dos, voz: voz);
      await _tocar(tester, 'La colazione');

      expect(find.textContaining('instalá la voz italiana'), findsOneWidget);
      // Y no ofrece ni el altavoz ni la velocidad, que no harían nada.
      expect(find.byIcon(Icons.volume_up_outlined), findsNothing);
      expect(find.text('Lento'), findsNothing);
    });
  });

  testWidgets('los cuentos salen ordenados por nivel', (tester) async {
    await _abrir(tester, _dos);

    final facil = tester.getRect(find.text('La colazione'));
    final dificil = tester.getRect(find.text('Il lavoro'));
    expect(facil.top, lessThan(dificil.top));
  });
}
