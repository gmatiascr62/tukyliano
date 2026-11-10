import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/datos/repositorio_podcast.dart';
import 'package:tukyliano/modelos/episodio.dart';
import 'package:tukyliano/pantallas/pantalla_podcast.dart';

import 'voz_falsa.dart';

/// Un episodio de mentira: dos turnos, uno de cada uno, con una palabra en el
/// glosario.
const _unEpisodio = '''
{
  "version": 2,
  "episodios": [
    {
      "titulo": "Il caffè",
      "deQueVa": "Hablan del café.",
      "glosario": [
        { "it": "sonno", "es": "sueño" }
      ],
      "lineas": [
        { "quien": "giulia", "it": "Come stai?", "es": "¿Cómo estás?" },
        { "quien": "lorenzo", "it": "Molto bene, grazie.", "es": "Muy bien, gracias." },
        { "quien": "giulia", "it": "Io ho sonno.", "es": "Yo tengo sueño." }
      ]
    }
  ]
}
''';

RepositorioPodcast _repositorioCon(String json) =>
    RepositorioPodcast(leerAsset: (_) async => json);

/// Abre la pantalla y entra al primer episodio.
Future<VozFalsa> _abrir(
  WidgetTester tester, {
  String json = _unEpisodio,
  bool hayItaliano = true,
  int cuantasVoces = 2,
  bool entrar = true,
  bool deACadaUna = false,
}) async {
  final voz = VozFalsa(
    hayItaliano: hayItaliano,
    cuantasVoces: cuantasVoces,
    deACadaUna: deACadaUna,
  );
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: PantallaPodcast(repositorio: _repositorioCon(json), voz: voz),
    ),
  ));
  await tester.pumpAndSettle();
  if (entrar) {
    await tester.tap(find.text('Il caffè'));
    await tester.pumpAndSettle();
  }
  return voz;
}

Future<Podcast> _elPodcastDeVerdad() async =>
    Podcast.desdeJson(jsonDecode(await File('assets/podcast.json').readAsString()));

void main() {
  group('los episodios que viajan en la app', () {
    // Se lee el archivo del repositorio, no uno de mentira: si alguien le
    // rompe una coma al JSON o escribe mal un nombre, esto lo dice acá y no
    // en el celular.

    test('se leen todos', () async {
      final podcast = await _elPodcastDeVerdad();

      expect(podcast.episodios.length, greaterThanOrEqualTo(2));
      for (final episodio in podcast.episodios) {
        expect(episodio.titulo.trim(), isNotEmpty);
        expect(episodio.deQueVa.trim(), isNotEmpty);
        expect(episodio.lineas.length, greaterThan(10));
      }
    });

    test('todas las líneas tienen el italiano y la traducción', () async {
      for (final episodio in (await _elPodcastDeVerdad()).episodios) {
        for (final linea in episodio.lineas) {
          expect(linea.italiano.trim(), isNotEmpty);
          expect(linea.castellano.trim(), isNotEmpty,
              reason: 'sin traducción no sirve: "${linea.italiano}"');
        }
      }
    });

    test('cada palabra del glosario está en el texto del episodio', () async {
      // Si no está, la palabra nunca se puede tocar y el glosario miente. Una
      // letra mal escrita acá sería invisible en la pantalla.
      for (final episodio in (await _elPodcastDeVerdad()).episodios) {
        expect(episodio.glosario, isNotEmpty,
            reason: '${episodio.titulo} no tiene palabras para tocar');

        // Se pregunta igual que la pantalla, palabra por palabra: así el test
        // mide lo que de verdad se va a poder tocar, elisiones incluidas.
        final palabrasDelTexto =
            episodio.lineas.map((l) => l.italiano).join(' ').split(RegExp(r'\s+'));

        for (final palabra in episodio.glosario) {
          final sePuedeTocar = palabrasDelTexto
              .any((p) => episodio.queQuiereDecir(p) == palabra.castellano);
          expect(sePuedeTocar, isTrue,
              reason: '"${palabra.italiano}" no aparece en ${episodio.titulo}, '
                  'así que nunca se va a poder tocar');
        }
      }
    });

    test('hay un episodio contado por uno solo y otro entre dos', () async {
      // Son los dos formatos que se están comparando: el podcast clásico de
      // alguien hablando solo, y la conversación.
      final cuantasVoces = [
        for (final episodio in (await _elPodcastDeVerdad()).episodios)
          episodio.quienesHablan.length,
      ];

      expect(cuantasVoces, contains(1));
      expect(cuantasVoces, contains(2));
    });

    test('los tres tienen su audio grabado', () async {
      for (final episodio in (await _elPodcastDeVerdad()).episodios) {
        expect(episodio.grabado, isTrue,
            reason: '${episodio.titulo} se escucharía con el motor de voz');
      }
    });

    test('el archivo de audio de cada uno existe y pesa', () async {
      // Declararlo en el JSON y olvidarse de meterlo en assets/ es un error
      // que no se ve hasta que alguien toca Escuchar en el celular.
      for (final episodio in (await _elPodcastDeVerdad()).episodios) {
        final archivo = File('assets/audio/${episodio.audio}');
        expect(archivo.existsSync(), isTrue, reason: 'falta ${episodio.audio}');
        expect(archivo.lengthSync(), greaterThan(100 * 1024),
            reason: '${episodio.audio} está vacío o cortado');
      }
    });

    test('los tiempos arrancan en cero y van siempre para adelante', () async {
      // Un tiempo fuera de orden desincroniza la frase marcada de ahí en
      // adelante, y no se nota leyendo el JSON.
      for (final episodio in (await _elPodcastDeVerdad()).episodios) {
        final cuando = [for (final l in episodio.lineas) l.desde!];
        expect(cuando.first, Duration.zero, reason: episodio.titulo);
        for (var i = 1; i < cuando.length; i++) {
          expect(cuando[i], greaterThan(cuando[i - 1]),
              reason: '${episodio.titulo}, frase $i');
        }
      }
    });

    test('cada frase dura algo razonable', () async {
      // Entre una y otra hay 350 ms de silencio, así que el salto mínimo es
      // ese más lo que tarda en decirla. Un salto de dos décimas significaría
      // que una frase quedó sin audio.
      for (final episodio in (await _elPodcastDeVerdad()).episodios) {
        final cuando = [for (final l in episodio.lineas) l.desde!];
        for (var i = 1; i < cuando.length; i++) {
          final dura = cuando[i] - cuando[i - 1];
          expect(dura, greaterThan(const Duration(milliseconds: 700)),
              reason: '${episodio.titulo}, frase ${i - 1} dura casi nada');
          expect(dura, lessThan(const Duration(seconds: 25)),
              reason: '${episodio.titulo}, frase ${i - 1} dura demasiado');
        }
      }
    });
  });

  group('leer el archivo', () {
    test('un renglón roto no tira abajo el episodio', () {
      final podcast = Podcast.desdeJson(jsonDecode('''
        {"episodios": [{"titulo": "T", "deQueVa": "D", "lineas": [
          {"quien": "giulia", "it": "Ciao", "es": "Hola"},
          {"quien": "nadie", "it": "x", "es": "y"},
          {"quien": "lorenzo", "it": "Ciao", "es": "Hola"}
        ]}]}
      '''));

      expect(podcast.episodios.first.lineas.length, 2);
    });

    test('un episodio sin líneas no aparece', () {
      final podcast = Podcast.desdeJson(jsonDecode('''
        {"episodios": [{"titulo": "T", "deQueVa": "D", "lineas": []}]}
      '''));

      expect(podcast.episodios, isEmpty);
    });

    test('sin glosario el episodio se lee igual', () {
      final podcast = Podcast.desdeJson(jsonDecode('''
        {"episodios": [{"titulo": "T", "deQueVa": "D", "lineas": [
          {"quien": "giulia", "it": "Ciao", "es": "Hola"}
        ]}]}
      '''));

      expect(podcast.episodios.first.glosario, isEmpty);
      expect(podcast.episodios.first.queQuiereDecir('Ciao'), isNull);
    });

    test('un archivo que no se puede leer no rompe la app', () async {
      final repositorio = RepositorioPodcast(
        leerAsset: (_) async => throw Exception('no está'),
      );

      expect((await repositorio.cargar()).episodios, isEmpty);
    });
  });

  group('buscar una palabra', () {
    const episodio = Episodio(
      titulo: 'T',
      deQueVa: 'D',
      lineas: [
        LineaDelEpisodio(
          quien: QuienHabla.lorenzo,
          italiano: 'Ho sonno.',
          castellano: 'Tengo sueño.',
        ),
      ],
      glosario: [
        PalabraDelEpisodio(italiano: 'sonno', castellano: 'sueño'),
      ],
    );

    test('encuentra la palabra aunque venga pegada a un signo', () {
      // En el texto viene "sonno." con el punto pegado.
      expect(episodio.queQuiereDecir('sonno.'), 'sueño');
      expect(episodio.queQuiereDecir('Sonno'), 'sueño');
      expect(episodio.queQuiereDecir(' sonno '), 'sueño');
    });

    test('la encuentra con el artículo pegado adelante', () {
      // El italiano está lleno de elisiones: l'Italia, un'idea,
      // nell'Ottocento. Buscando la palabra entera no se encontraría ninguna.
      const conElisiones = Episodio(
        titulo: 'T',
        deQueVa: 'D',
        lineas: [
          LineaDelEpisodio(
            quien: QuienHabla.lorenzo,
            italiano: "Nell'Ottocento tutto cambia.",
            castellano: 'En el siglo XIX todo cambia.',
          ),
        ],
        glosario: [
          PalabraDelEpisodio(italiano: 'Ottocento', castellano: 'el siglo XIX'),
        ],
      );

      expect(conElisiones.queQuiereDecir("Nell'Ottocento"), 'el siglo XIX');
    });

    test('una palabra que no está no inventa nada', () {
      expect(episodio.queQuiereDecir('caffè'), isNull);
      expect(episodio.queQuiereDecir('  '), isNull);
    });
  });

  group('quién cuenta cada episodio', () {
    LineaDelEpisodio deQuien(QuienHabla quien) =>
        LineaDelEpisodio(quien: quien, italiano: 'Ciao', castellano: 'Hola');

    test('contado por uno solo dice un nombre', () {
      final episodio = Episodio(
        titulo: 'T',
        deQueVa: 'D',
        lineas: [deQuien(QuienHabla.lorenzo), deQuien(QuienHabla.lorenzo)],
      );

      expect(episodio.quienLoCuenta, 'Lorenzo');
    });

    test('entre dos dice los dos, en el orden en que hablan', () {
      final episodio = Episodio(
        titulo: 'T',
        deQueVa: 'D',
        lineas: [deQuien(QuienHabla.giulia), deQuien(QuienHabla.lorenzo)],
      );

      expect(episodio.quienLoCuenta, 'Giulia y Lorenzo');
    });
  });

  group('la lista', () {
    testWidgets('muestra los episodios con de qué van', (tester) async {
      await _abrir(tester, entrar: false);

      expect(find.text('Il caffè'), findsOneWidget);
      expect(find.text('Hablan del café.'), findsOneWidget);
    });

    testWidgets('sin episodios lo dice en vez de quedarse en blanco',
        (tester) async {
      await _abrir(tester, json: '{"episodios": []}', entrar: false);

      expect(find.textContaining('Todavía no hay episodios'), findsOneWidget);
    });
  });

  group('el reproductor', () {
    testWidgets('muestra el título y las frases', (tester) async {
      await _abrir(tester);

      expect(find.text('Come stai?'), findsOneWidget);
      expect(find.textContaining('Io ho sonno'), findsOneWidget);
    });

    testWidgets('la traducción no está a la vista hasta que se pide',
        (tester) async {
      await _abrir(tester);

      expect(find.text('¿Cómo estás?'), findsNothing);

      await tester.longPress(find.text('Come stai?'));
      await tester.pumpAndSettle();

      expect(find.text('¿Cómo estás?'), findsOneWidget);
    });

    testWidgets('al escuchar, Giulia y Lorenzo se turnan de verdad',
        (tester) async {
      // Es lo que distingue una conversación de un cuento leído: que cada
      // turno suene con la voz de quien habla.
      final voz = await _abrir(tester);

      await tester.tap(find.text('Escuchar'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(voz.dicho, ['Come stai?', 'Molto bene, grazie.', 'Io ho sonno.']);
      expect(voz.conQueVoz, ['Giulia', 'Lorenzo', 'Giulia']);
    });

    testWidgets('al parar y seguir, retoma donde quedó', (tester) async {
      // Antes volvía a empezar desde la primera frase, que en un episodio de
      // tres minutos obliga a escuchar de nuevo todo lo ya escuchado.
      final voz = await _abrir(tester);

      // Se para en la segunda línea tocándola: queda marcada como la actual.
      // Se elige una sin palabra subrayada, para que el toque caiga en el
      // renglón y no en la palabra.
      await tester.tap(find.text('Molto bene, grazie.'));
      await tester.pumpAndSettle();
      voz.dicho.clear();

      expect(find.text('Seguir'), findsOneWidget);
      await tester.tap(find.text('Seguir'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(voz.dicho, ['Molto bene, grazie.', 'Io ho sonno.'],
          reason: 'no tiene que volver al principio');
    });

    testWidgets('se puede volver al principio a propósito', (tester) async {
      final voz = await _abrir(tester);

      await tester.tap(find.text('Molto bene, grazie.'));
      await tester.pumpAndSettle();
      voz.dicho.clear();

      await tester.tap(find.byIcon(Icons.replay));
      await tester.pumpAndSettle();

      expect(find.text('Escuchar'), findsOneWidget);
      await tester.tap(find.text('Escuchar'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(voz.dicho, ['Come stai?', 'Molto bene, grazie.', 'Io ho sonno.']);
    });

    testWidgets('tocar una palabra del glosario muestra qué quiere decir',
        (tester) async {
      await _abrir(tester);

      // El reconocedor del toque está adentro del texto, así que se busca por
      // el span y se lo toca donde cae.
      final texto = tester.widget<Text>(find.textContaining('Io ho sonno'));
      final spans = (texto.textSpan! as TextSpan).children!;
      final tocable = spans.whereType<TextSpan>().firstWhere(
            (s) => s.recognizer != null,
          );

      expect(tocable.text!.trim(), 'sonno.');

      (tocable.recognizer as dynamic).onTap();
      await tester.pumpAndSettle();

      expect(find.textContaining('sueño'), findsWidgets);
    });

    testWidgets('con una sola voz instalada igual se escucha', (tester) async {
      // Se pierde el ida y vuelta, pero el episodio se escucha. Callarse
      // sería peor.
      final voz = await _abrir(tester, cuantasVoces: 1);

      await tester.tap(find.text('Escuchar'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(voz.dicho, ['Come stai?', 'Molto bene, grazie.', 'Io ho sonno.']);
    });

    testWidgets('sin la voz italiana avisa y no habla', (tester) async {
      // La voz de mentira revienta si se la hace hablar sin italiano, así que
      // si esto pasa es porque de verdad no habló.
      await _abrir(tester, hayItaliano: false);

      expect(find.textContaining('no tiene la voz italiana'), findsOneWidget);
      expect(find.text('Escuchar'), findsNothing);
    });

    testWidgets('sin voz italiana igual se puede leer y traducir',
        (tester) async {
      await _abrir(tester, hayItaliano: false);

      await tester.longPress(find.text('Come stai?'));
      await tester.pumpAndSettle();

      expect(find.text('¿Cómo estás?'), findsOneWidget);
    });

    testWidgets('lo lento se puede pedir', (tester) async {
      final voz = await _abrir(tester);

      await tester.tap(find.text('Lento'));
      await tester.pumpAndSettle();

      expect(voz.lenta, isTrue);
    });

    testWidgets('el renglón que suena queda a la vista en el medio',
        (tester) async {
      // Es el error que se vio en el celular: después de un rato, la parte
      // que iba leyendo se escapaba por arriba. Pasaba porque el
      // desplazamiento se calculaba suponiendo que todos los renglones miden
      // igual, y no miden igual.
      //
      // Dos cosas hacen que este test sirva y no pase de casualidad:
      // frases de largos mezclados, y mirar en el MEDIO. Al final no se nota,
      // porque el desplazamiento se topa con el fondo de la lista y queda
      // bien sin querer.
      final lineas = [
        for (var i = 0; i < 40; i++)
          {
            'quien': i.isEven ? 'giulia' : 'lorenzo',
            'it': i % 3 == 0
                ? 'Frase $i.'
                : 'Questa è la frase numero $i e dura parecchio perché '
                    'occupa più di una riga sullo schermo del telefono.',
            'es': 'Frase $i.',
          },
      ];
      final json = jsonEncode({
        'episodios': [
          {'titulo': 'Il caffè', 'deQueVa': 'Largo.', 'lineas': lineas},
        ],
      });

      final voz = await _abrir(tester, json: json, deACadaUna: true);
      await tester.tap(find.text('Escuchar'));
      await tester.pump();

      // Se avanza frase por frase hasta la mitad del episodio.
      const hastaCual = 20;
      for (var i = 0; i < hastaCual; i++) {
        voz.seguir();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.pump(const Duration(milliseconds: 400));

      expect(voz.dicho.length, greaterThan(hastaCual));

      final sonando = lineas[voz.dicho.length - 1]['it']!;
      final pantalla = tester.getRect(find.byType(ListView));
      final renglon = find.text(sonando);

      expect(renglon, findsOneWidget,
          reason: 'la frase que suena ni se dibujó: "$sonando"');

      final donde = tester.getRect(renglon);
      expect(donde.top, greaterThanOrEqualTo(pantalla.top - 1),
          reason: 'se escapó por arriba: "$sonando"');
      expect(donde.bottom, lessThanOrEqualTo(pantalla.bottom + 1),
          reason: 'se escapó por abajo: "$sonando"');
    });

    testWidgets('se puede volver a la lista', (tester) async {
      await _abrir(tester);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Hablan del café.'), findsOneWidget);
    });
  });
}
