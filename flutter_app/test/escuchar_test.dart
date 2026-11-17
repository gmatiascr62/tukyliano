// Las tres pastillas de Escuchar.
//
// Lo que se prueba acá no es el contenido de cada una —eso lo prueban sus
// propios tests— sino que la pastilla lleve a donde dice, y que cambiar de
// una a otra arme la pantalla de nuevo en vez de quedarse con el estado de
// la anterior.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/datos/repositorio_diccionario.dart';
import 'package:tukyliano/datos/repositorio_lecturas.dart';
import 'package:tukyliano/modelos/lectura.dart';
import 'package:tukyliano/pantallas/pantalla_escuchar.dart';
import 'package:tukyliano/pantallas/pantalla_lecturas.dart';
import 'package:tukyliano/tema.dart';

import 'descargas_falsas.dart';
import 'reproductor_falso.dart';
import 'util_pantalla.dart';

Future<void> _abrir(WidgetTester tester, {QueSeEscucha? empezarEn}) async {
  usarPantallaDeCelular(tester);
  await tester.pumpWidget(MaterialApp(
    theme: Tema.datos,
    home: Scaffold(
      body: PantallaEscuchar(
        reproductor: ReproductorFalso(),
        empezarEn: empezarEn ?? QueSeEscucha.podcast,
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('están las tres y se ven', (tester) async {
    await _abrir(tester);

    for (final cual in QueSeEscucha.values) {
      expect(find.text(cual.nombre), findsOneWidget, reason: cual.nombre);
    }
  });

  testWidgets('cada lectura sabe de qué catálogo sale', (tester) async {
    // Es lo único que las distingue: la misma pantalla con otro archivo.
    // Si estos dos se cruzan, Pinocchio muestra las fábulas y nadie se
    // entera hasta abrirlo.
    expect(QueSeEscucha.favole.archivo, 'assets/favole.json');
    expect(QueSeEscucha.favole.clave, 'favole');
    expect(QueSeEscucha.pinocchio.archivo, 'assets/pinocchio.json');
    expect(QueSeEscucha.pinocchio.clave, 'capitulos');

    // El podcast no es una lectura: sus episodios vienen de otro lado.
    expect(QueSeEscucha.podcast.esLectura, isFalse);
    expect(QueSeEscucha.favole.esLectura, isTrue);
    expect(QueSeEscucha.pinocchio.esLectura, isTrue);
  });

  testWidgets('se puede entrar derecho a Pinocchio', (tester) async {
    await _abrir(tester, empezarEn: QueSeEscucha.pinocchio);
    await tester.pump();

    // La pantalla de lecturas se armó con el catálogo de Pinocchio.
    expect(find.byKey(const ValueKey('pinocchio')), findsOneWidget);
  });

  testWidgets('cambiar de pastilla arma la pantalla de nuevo', (tester) async {
    // Con la misma key, Flutter reusaría el estado y la lista de Pinocchio
    // arrancaría mostrando lo que quedó de las fábulas.
    await _abrir(tester, empezarEn: QueSeEscucha.favole);
    await tester.pump();
    expect(find.byKey(const ValueKey('favole')), findsOneWidget);

    await tester.tap(find.text('Pinocchio'));
    await tester.pump();

    expect(find.byKey(const ValueKey('pinocchio')), findsOneWidget);
    expect(find.byKey(const ValueKey('favole')), findsNothing);
  });

  _elCatalogoDePinocchio();
}

/// El catálogo de Pinocchio, leído como lo lee la app.
///
/// No alcanza con que el archivo exista: tiene que tener los treinta y seis
/// capítulos, cada uno con su audio, su duración, su peso y su texto. Si
/// alguno viene vacío, en la app se ve una fila que no suena y no se sabe
/// por qué.
void _elCatalogoDePinocchio() {
  group('el catálogo de Pinocchio', () {
    late Lecturas catalogo;

    setUpAll(() async {
      // Con dart:io y no con rootBundle: en un archivo que además tiene
      // tests de widget, leer un asset con rootBundle no termina nunca
      // —el reloj es falso y esa espera nunca se resuelve— y el test se
      // cuelga doce minutos hasta que lo matan.
      catalogo = await RepositorioLecturas(
        leerAsset: (cual) async => File(cual).readAsStringSync(),
        archivo: QueSeEscucha.pinocchio.archivo,
        clave: QueSeEscucha.pinocchio.clave,
      ).cargar();
    });

    test('están los treinta y seis', () {
      expect(catalogo.lecturas.length, 36);
    });

    test('cada uno tiene todo lo que hace falta para sonar', () {
      for (final capitulo in catalogo.lecturas) {
        expect(capitulo.archivo, endsWith('.mp3'), reason: capitulo.titulo);
        expect(capitulo.segundos, greaterThan(0), reason: capitulo.titulo);
        expect(capitulo.bytes, greaterThan(0), reason: capitulo.titulo);
        expect(capitulo.renglones, isNotEmpty, reason: capitulo.titulo);
        expect(capitulo.titulo.trim(), isNotEmpty);
      }
    });

    test('los títulos dicen de qué va el capítulo, no el número romano', () {
      // Salían "II.", "III." cuando el título se sacaba del primer párrafo
      // de la página. Ahora salen del índice del libro.
      for (final capitulo in catalogo.lecturas) {
        expect(capitulo.titulo.length, greaterThan(12),
            reason: capitulo.titulo);
      }
      expect(catalogo.lecturas[3].titulo, contains('Grillo-parlante'));
    });

    test('se baja de donde dice el catálogo, y lo firma Collodi', () {
      expect(catalogo.base, contains('pinocchio-1'));
      expect(catalogo.deQuien, contains('Collodi'));
      expect(catalogo.donde(catalogo.lecturas.first), startsWith('https://'));
    });

    testWidgets('no se ofrece bajar los 131 MB de un saque',
        (tester) async {
      // Con las fábulas, "bajar todas" son 18 MB y es una comodidad. Con
      // Pinocchio son 131, y un botón que con un toque se lleva 131 MB de
      // datos no es una comodidad: es una trampa para el que lo toca en la
      // calle creyendo que es como el otro.
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(MaterialApp(
        theme: Tema.datos,
        home: Scaffold(
          body: PantallaLecturas(
            repositorio: RepositorioLecturas(
              leerAsset: (cual) async => File(cual).readAsStringSync(),
              archivo: QueSeEscucha.pinocchio.archivo,
              clave: QueSeEscucha.pinocchio.clave,
            ),
            descargas: DescargasFalsas(),
            reproductor: ReproductorFalso(),
            diccionario: RepositorioDiccionario(
              leerAsset: (_) async => '{"version":1,"it":{},"es":{}}',
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Bajar todas'), findsNothing);
      // Y cada capítulo se sigue pudiendo bajar al tocarlo.
      expect(find.textContaining('Come andò che maestro Ciliegia'),
          findsOneWidget);
    });

    test('no se coló nada de Wikisource en el texto', () {
      // El número de página del libro escaneado, con su enlace de editar,
      // viene en el medio del texto: "gli era entrato addosso una gran
      // [p. 9 modifica]paura". Doscientos cuarenta renglones lo tenían, y
      // no se ve hasta leer una fábula entera.
      final sucia = RegExp(r'\[p\.|modifica|mw-parser|dc:title');
      for (final capitulo in catalogo.lecturas) {
        for (final renglon in capitulo.renglones) {
          expect(sucia.hasMatch(renglon.texto), isFalse,
              reason: '${capitulo.titulo}: ${renglon.texto}');
        }
      }
    });

    test('ningún renglón es tan largo que no se pueda seguir', () {
      // Collodi escribe frases larguísimas unidas por comas: la más larga
      // del libro son 2308 caracteres, dos minutos y medio de audio en un
      // solo renglón. Iluminar eso no dice dónde va el audio.
      for (final capitulo in catalogo.lecturas) {
        for (final renglon in capitulo.renglones) {
          expect(renglon.texto.length, lessThanOrEqualTo(260),
              reason: renglon.texto);
        }
      }
    });

    test('no hay audio sin texto en el medio de un capítulo', () {
      // **Este es el test que faltaba.** Todos los de arriba miran lo que
      // está en el catálogo; ninguno miraba lo que *falta*, y durante un
      // rato faltaron párrafos enteros de Collodi sin que se notara: el
      // texto que quedaba era impecable, solo que con agujeros. En el
      // capítulo 1 eran veintidós segundos donde se presenta maestro
      // Ciliegia, en el 16 veinticinco de la carrozzina. El audio los lee
      // y en la pantalla el renglón iluminado se queda clavado.
      //
      // Un párrafo que falta se ve así: un hueco entre el final de un
      // renglón y el arranque del siguiente. Con el texto completo el
      // hueco más grande de un capítulo es de 1,9 segundos —la pausa que
      // hace quien lee entre dos párrafos—, así que ocho segundos es
      // holgado para no saltar por una pausa larga y sigue agarrando
      // cualquier frase que se haya perdido.
      const cuantoSeAguanta = Duration(seconds: 8);
      var conTiempos = 0;

      for (final capitulo in catalogo.lecturas) {
        final marcados =
            capitulo.renglones.where((r) => r.desde != null).toList();
        if (marcados.isEmpty) continue;
        conTiempos++;

        for (var i = 0; i < marcados.length - 1; i++) {
          final termina = marcados[i].hasta ?? marcados[i].desde!;
          final arranca = marcados[i + 1].desde!;
          expect(arranca - termina, lessThan(cuantoSeAguanta),
              reason: '${capitulo.titulo}: entre "${marcados[i].texto}" y '
                  '"${marcados[i + 1].texto}" hay audio que no tiene '
                  'renglón');
        }
      }

      // Si ningún capítulo tuviera tiempos, el test pasaría sin mirar
      // nada y no se notaría.
      expect(conTiempos, greaterThan(0),
          reason: 'ningún capítulo tiene tiempos: este test no probó nada');
    });

    test('ni las leyendas ni los resúmenes son renglones', () {
      // El libro escaneado trae ilustraciones con su leyenda, y el resumen
      // de cada capítulo arriba. Nada de eso se lee en voz alta, así que
      // como renglón es un renglón que no se ilumina nunca.
      //
      // Los tres de acá abajo entraban por tres caminos distintos, y son
      // tres y no uno a propósito: la primera versión de este test miraba
      // una sola leyenda —justo una de las que ya estaban arregladas— y
      // pasaba en verde con las otras adentro. Un test que mira un caso
      // puntual de una familia de bugs no cubre la familia.
      const noVan = [
        // Leyenda en un cajón flotante al costado, no centrada.
        'Un grosso Falco venne a posarsi sul davanzale della finestra.',
        // Resumen del capítulo, colado en el medio del cuento.
        'Dopo cinque mesi di cuccagna, Pinocchio con sua grande meraviglia '
            'sente spuntarsi un bel pajo d’orecchie asinine, e diventa un '
            'ciuchino, con la coda e tutto.',
        'Pinocchio gettato in mare, è mangiato dai pesci, e ritorna ad '
            'essere un burattino come prima: ma mentre nuota per salvarsi, '
            'è ingoiato dal terribile Pesce-cane.',
        // Leyenda dentro de la tabla de la ilustración.
        'Il Can-barbone partì come un barbero.',
      ];
      for (final capitulo in catalogo.lecturas) {
        for (final renglon in capitulo.renglones) {
          expect(noVan, isNot(contains(renglon.texto)),
              reason: '${capitulo.titulo}: "${renglon.texto}" no se lee en '
                  'el audio');
        }
      }

      // Y lo que sí tiene que estar: las dos mitades del párrafo que la
      // ilustración partía al medio, pegadas.
      final texto16 =
          catalogo.lecturas[15].renglones.map((r) => r.texto).join(' ');
      expect(texto16, contains('cento pariglie di topini bianchi'));
      // La leyenda se va, pero la frase del cuento que repetía queda.
      expect(texto16, contains('venne a posarsi sul davanzale'));

      // El párrafo del capítulo 1 que se perdía entero: sin él, el audio
      // presenta a maestro Ciliegia y en la pantalla no pasa nada.
      final texto1 =
          catalogo.lecturas[0].renglones.map((r) => r.texto).join(' ');
      expect(texto1, contains('mastr’Antonio'));
      expect(texto1, contains('come una ciliegia matura'));

      // Y un diálogo que además es leyenda —el capítulo 9 ilustra la
      // pregunta y tres líneas después alguien la dice— tiene que quedar:
      // el control de que no se cuelen leyendas no puede borrar diálogo.
      final texto9 =
          catalogo.lecturas[8].renglones.map((r) => r.texto).join(' ');
      expect(texto9, contains('Vuoi darmi quattro soldi'));
    });

    test('el texto está partido en oraciones, no en párrafos', () {
      // En prosa un párrafo dura entre medio minuto y un minuto, y un
      // renglón iluminado de un minuto no dice dónde va el audio.
      final renglones =
          catalogo.lecturas.fold<int>(0, (n, c) => n + c.renglones.length);
      final segundos =
          catalogo.lecturas.fold<int>(0, (n, c) => n + c.segundos);
      expect(segundos / renglones, lessThan(12));
    });
  });
}
