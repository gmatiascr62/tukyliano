import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/datos/repositorio_articoli.dart';
import 'package:tukyliano/logica/articulos.dart';
import 'package:tukyliano/pantallas/pantalla_articoli.dart';
import 'package:tukyliano/tema.dart';

import 'util_pantalla.dart';

/// Una sola palabra, así la pregunta es siempre la misma y se puede afirmar
/// cuál es la respuesta correcta.
const _soloZaino = '''
  {
    "version": 1,
    "clases": {
      "m_s_impura": {
        "determinativo": "lo", "indeterminativo": "uno",
        "determinativo_plural": "gli",
        "partitivo": "dello", "partitivo_plural": "degli",
        "explicacion": "Masculino que empieza con s + consonante, z, gn, ps, pn, x o y"
      }
    },
    "sustantivos": [
      {"it": "zaino", "it_plural": "zaini", "clase": "m_s_impura",
       "es": "mochila", "es_plural": "mochilas", "es_genero": "f",
       "nota": "En español \\"mochila\\" es femenino, pero zaino es masculino"}
    ]
  }
''';

/// Una palabra que no se cuenta, para el partitivo singular.
const _soloZucchero = '''
  {
    "version": 1,
    "clases": {
      "m_s_impura": {
        "determinativo": "lo", "indeterminativo": "uno",
        "determinativo_plural": "gli",
        "partitivo": "dello", "partitivo_plural": "degli",
        "explicacion": "Masculino que empieza con s + consonante, z, gn, ps, pn, x o y"
      }
    },
    "sustantivos": [
      {"it": "zucchero", "clase": "m_s_impura", "es": "azúcar",
       "es_genero": "m", "incontable": true}
    ]
  }
''';

/// Una palabra que empieza con vocal, para el caso del apóstrofo.
const _soloAmico = '''
  {
    "version": 1,
    "clases": {
      "m_vocal": {"determinativo": "l'", "indeterminativo": "un",
       "determinativo_plural": "gli", "partitivo": "dell'",
       "partitivo_plural": "degli", "explicacion": "Masculino que empieza con vocal"}
    },
    "sustantivos": [
      {"it": "amico", "clase": "m_vocal", "es": "amigo", "es_genero": "m"}
    ]
  }
''';

RepositorioArticoli _repo(String json) => RepositorioArticoli(
      leerAsset: (_) async => json,
      cliente: MockClient((_) async => http.Response('', 404)),
      carpeta: () async => null,
    );

/// Se abre con una sola categoría para que la pregunta sea previsible: con las
/// tres mezcladas cada corrida saldría distinta y no se podría afirmar nada.
Future<void> _abrir(
  WidgetTester tester,
  String json, {
  CategoriaArticulo categoria = CategoriaArticulo.determinado,
}) async {
  usarPantallaDeCelular(tester);
  await tester.pumpWidget(MaterialApp(
    theme: Tema.datos,
    home: Scaffold(
      body: PantallaArticoli(
        repositorio: _repo(json),
        categorias: {categoria},
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester tester, String texto) async {
  await tester.tap(find.text(texto));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pregunta en español y muestra la palabra con puntos',
      (tester) async {
    await _abrir(tester, _soloZaino);

    // El género del español, aunque en italiano sea masculino.
    expect(find.text('la mochila'), findsOneWidget);
    expect(find.textContaining('· · ·'), findsOneWidget);
    expect(find.textContaining('zaino'), findsOneWidget);
    expect(find.text('Puntaje: 0/0'), findsOneWidget);
  });

  testWidgets('ofrece los cuatro artículos determinados', (tester) async {
    await _abrir(tester, _soloZaino);

    for (final articulo in ['il', 'lo', 'la', "l'"]) {
      expect(find.text(articulo), findsOneWidget);
    }
  });

  testWidgets('tocar un artículo reemplaza los puntos', (tester) async {
    await _abrir(tester, _soloZaino);

    await _tocar(tester, 'lo');

    expect(find.text('lo zaino'), findsOneWidget);
    expect(find.textContaining('· · ·'), findsNothing);
  });

  testWidgets('sin elegir artículo no se puede verificar', (tester) async {
    await _abrir(tester, _soloZaino);

    final boton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Verificar'),
    );
    expect(boton.onPressed, isNull);
  });

  testWidgets('se puede cambiar de artículo antes de verificar',
      (tester) async {
    await _abrir(tester, _soloZaino);

    await _tocar(tester, 'il');
    expect(find.text('il zaino'), findsOneWidget);

    await _tocar(tester, 'lo');
    expect(find.text('lo zaino'), findsOneWidget);
    expect(find.text('il zaino'), findsNothing);
  });

  group('al verificar', () {
    testWidgets('acertar suma puntaje y muestra la explicación',
        (tester) async {
      await _abrir(tester, _soloZaino);

      await _tocar(tester, 'lo');
      await _tocar(tester, 'Verificar');

      expect(find.text('¡Correcto!'), findsOneWidget);
      expect(find.text('Puntaje: 1/1'), findsOneWidget);
      expect(find.textContaining('s + consonante'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Siguiente'), findsOneWidget);
    });

    testWidgets('errar muestra cuál era y no suma', (tester) async {
      await _abrir(tester, _soloZaino);

      await _tocar(tester, 'la');
      await _tocar(tester, 'Verificar');

      expect(find.text('Va lo zaino'), findsOneWidget);
      expect(find.text('Puntaje: 0/1'), findsOneWidget);
      expect(find.text('¡Correcto!'), findsNothing);
    });

    testWidgets('la explicación incluye la nota de la palabra', (tester) async {
      // Es lo que evita que "la mochila → lo zaino" parezca un error de la app.
      await _abrir(tester, _soloZaino);

      await _tocar(tester, 'la');
      await _tocar(tester, 'Verificar');

      expect(find.textContaining('pero zaino es masculino'), findsOneWidget);
    });

    testWidgets('ya no se puede cambiar la respuesta', (tester) async {
      await _abrir(tester, _soloZaino);

      await _tocar(tester, 'la');
      await _tocar(tester, 'Verificar');
      await _tocar(tester, 'il');

      // Sigue mostrando lo que se contestó, no lo último que se tocó.
      expect(find.text('la zaino'), findsOneWidget);
      expect(find.text('Puntaje: 0/1'), findsOneWidget);
    });

    testWidgets('Siguiente limpia y deja otra pregunta', (tester) async {
      await _abrir(tester, _soloZaino);

      await _tocar(tester, 'lo');
      await _tocar(tester, 'Verificar');
      await _tocar(tester, 'Siguiente');

      expect(find.textContaining('· · ·'), findsOneWidget);
      expect(find.text('¡Correcto!'), findsNothing);
      // El puntaje acumulado se mantiene.
      expect(find.text('Puntaje: 1/1'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Verificar'), findsOneWidget);
    });
  });

  group('indeterminado', () {
    testWidgets('pregunta con "una" y ofrece los cuatro indeterminados',
        (tester) async {
      await _abrir(tester, _soloZaino,
          categoria: CategoriaArticulo.indeterminado);

      expect(find.text('una mochila'), findsOneWidget);
      for (final articulo in ['un', 'uno', 'una', "un'"]) {
        expect(find.text(articulo), findsOneWidget);
      }
    });

    testWidgets('la respuesta correcta es uno, no un', (tester) async {
      await _abrir(tester, _soloZaino,
          categoria: CategoriaArticulo.indeterminado);

      await _tocar(tester, 'un');
      await _tocar(tester, 'Verificar');

      expect(find.text('Va uno zaino'), findsOneWidget);
      expect(find.text('Puntaje: 0/1'), findsOneWidget);
    });
  });

  group('plural', () {
    testWidgets('pregunta en plural y muestra la palabra en plural',
        (tester) async {
      await _abrir(tester, _soloZaino, categoria: CategoriaArticulo.plural);

      expect(find.text('las mochilas'), findsOneWidget);
      expect(find.textContaining('zaini'), findsOneWidget);
      expect(find.textContaining('zaino'), findsNothing);
    });

    testWidgets('ofrece solamente tres artículos', (tester) async {
      await _abrir(tester, _soloZaino, categoria: CategoriaArticulo.plural);

      for (final articulo in ['i', 'gli', 'le']) {
        expect(find.text(articulo), findsOneWidget);
      }
      // Los del singular no están.
      for (final articulo in ['il', 'lo', 'la', 'uno']) {
        expect(find.text(articulo), findsNothing);
      }
    });

    testWidgets('acertar el plural suma', (tester) async {
      await _abrir(tester, _soloZaino, categoria: CategoriaArticulo.plural);

      await _tocar(tester, 'gli');
      await _tocar(tester, 'Verificar');

      expect(find.text('¡Correcto!'), findsOneWidget);
      expect(find.text('Puntaje: 1/1'), findsOneWidget);
    });

    testWidgets('una palabra sin plural no aparece en esta categoría',
        (tester) async {
      const soloLatte = '''
        {
          "version": 1,
          "clases": {
            "m_consonante": {"determinativo": "il", "indeterminativo": "un",
             "determinativo_plural": "i", "explicacion": "Masculino con consonante"}
          },
          "sustantivos": [
            {"it": "latte", "clase": "m_consonante", "es": "leche"}
          ]
        }
      ''';
      await _abrir(tester, soloLatte, categoria: CategoriaArticulo.plural);

      expect(find.textContaining('Todavía no hay palabras'), findsOneWidget);
    });
  });

  group('partitivo plural', () {
    testWidgets('pregunta con "unas" y ofrece dei/degli/delle', (tester) async {
      await _abrir(tester, _soloZaino,
          categoria: CategoriaArticulo.partitivoPlural);

      expect(find.text('unas mochilas'), findsOneWidget);
      for (final articulo in ['dei', 'degli', 'delle']) {
        expect(find.text(articulo), findsOneWidget);
      }
      // No se ofrecen los determinados plurales.
      for (final articulo in ['i', 'gli', 'le']) {
        expect(find.text(articulo), findsNothing);
      }
    });

    testWidgets('acertar suma y explica qué es el partitivo', (tester) async {
      await _abrir(tester, _soloZaino,
          categoria: CategoriaArticulo.partitivoPlural);

      await _tocar(tester, 'degli');
      await _tocar(tester, 'Verificar');

      expect(find.text('¡Correcto!'), findsOneWidget);
      expect(find.text('Puntaje: 1/1'), findsOneWidget);
      expect(find.textContaining('no tiene "unos/unas"'), findsOneWidget);
    });
  });

  group('partitivo singular', () {
    testWidgets('pregunta con "algo de" y ofrece del/dello/della/dell\'',
        (tester) async {
      await _abrir(tester, _soloZucchero,
          categoria: CategoriaArticulo.partitivo);

      expect(find.text('algo de azúcar'), findsOneWidget);
      for (final articulo in ['del', 'dello', 'della', "dell'"]) {
        expect(find.text(articulo), findsOneWidget);
      }
    });

    testWidgets('errar muestra cuál era y explica la contracción',
        (tester) async {
      await _abrir(tester, _soloZucchero,
          categoria: CategoriaArticulo.partitivo);

      await _tocar(tester, 'del');
      await _tocar(tester, 'Verificar');

      expect(find.text('Va dello zucchero'), findsOneWidget);
      expect(find.textContaining('di + il = del'), findsOneWidget);
    });

    testWidgets('una palabra que se cuenta no aparece acá', (tester) async {
      await _abrir(tester, _soloZaino, categoria: CategoriaArticulo.partitivo);

      expect(find.textContaining('Todavía no hay palabras'), findsOneWidget);
    });

    testWidgets('una incontable no aparece en el indeterminado',
        (tester) async {
      await _abrir(tester, _soloZucchero,
          categoria: CategoriaArticulo.indeterminado);

      expect(find.textContaining('Todavía no hay palabras'), findsOneWidget);
    });
  });

  group('la explicación no queda tapada por el botón', () {
    // Si el hueco fuera de alto fijo, el botón se le montaría encima.
    Future<void> verificarQueNoSeSolapa(WidgetTester tester) async {
      final explicacion = tester.getRect(find.textContaining('s + consonante'));
      final boton =
          tester.getRect(find.widgetWithText(ElevatedButton, 'Siguiente'));

      expect(explicacion.bottom, lessThanOrEqualTo(boton.top),
          reason: 'la explicación se solapa con el botón');
    }

    testWidgets('con la regla y la nota', (tester) async {
      await _abrir(tester, _soloZaino);

      await _tocar(tester, 'la');
      await _tocar(tester, 'Verificar');

      await verificarQueNoSeSolapa(tester);
    });

    testWidgets('con la regla y la ayuda del partitivo, que es la más larga',
        (tester) async {
      await _abrir(tester, _soloZucchero,
          categoria: CategoriaArticulo.partitivo);

      await _tocar(tester, 'del');
      await _tocar(tester, 'Verificar');

      await verificarQueNoSeSolapa(tester);
      // Y la ayuda tampoco.
      final ayuda = tester.getRect(find.textContaining('di + il = del'));
      final boton =
          tester.getRect(find.widgetWithText(ElevatedButton, 'Siguiente'));
      expect(ayuda.bottom, lessThanOrEqualTo(boton.top));
    });
  });

  testWidgets('el apóstrofo va pegado a la palabra', (tester) async {
    await _abrir(tester, _soloAmico);

    await _tocar(tester, "l'");

    expect(find.text("l'amico"), findsOneWidget);
    expect(find.text("l' amico"), findsNothing);
  });

  testWidgets('sin palabras cargadas lo avisa', (tester) async {
    await _abrir(tester, '{"version": 1, "clases": {}, "sustantivos": []}');

    expect(find.textContaining('Todavía no hay palabras'), findsOneWidget);
  });

  testWidgets('un JSON roto no rompe la pantalla', (tester) async {
    await _abrir(tester, 'esto no es JSON');

    expect(find.textContaining('Todavía no hay palabras'), findsOneWidget);
  });
}
