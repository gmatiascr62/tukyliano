import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/datos/descarga_modelo.dart';
import 'package:tukyliano/logica/capacidad.dart';
import 'package:tukyliano/pantallas/pantalla_modelo.dart';
import 'package:tukyliano/tema.dart';

import 'descarga_falsa.dart';
import 'util_pantalla.dart';

/// Abre la pantalla y devuelve la lista donde va a quedar la ruta cuando
/// termine de bajar.
Future<List<String>> _abrir(
  WidgetTester tester, {
  DescargaFalsa? descarga,
  Capacidad? capacidad,
}) async {
  final listo = <String>[];
  usarPantallaDeCelular(tester);
  await tester.pumpWidget(MaterialApp(
    theme: Tema.datos,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: PantallaModelo(
          descarga: descarga ?? DescargaFalsa(),
          capacidad: capacidad ??
              const Capacidad(memoriaMb: 8192, queTanBien: QueTanBien.bien),
          alTerminar: listo.add,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return listo;
}
void main() {
  group('antes de bajar', () {
    testWidgets('dice cuánto pesa y que es una sola vez', (tester) async {
      await _abrir(tester);

      expect(find.textContaining('una sola vez'), findsOneWidget);
      expect(find.textContaining('MB'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Bajar la IA'), findsOneWidget);
    });

    testWidgets('explica que después funciona sin internet', (tester) async {
      await _abrir(tester);

      expect(find.textContaining('sin internet'), findsOneWidget);
      expect(find.textContaining('wifi'), findsOneWidget);
    });

    testWidgets('con poca memoria avisa, pero deja', (tester) async {
      await _abrir(
        tester,
        capacidad: const Capacidad(memoriaMb: 4096, queTanBien: QueTanBien.justo),
      );

      expect(find.textContaining('lento'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Bajar la IA'),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('con memoria de menos no deja empezar', (tester) async {
      // Bajarse cientos de megas para que después la app se cierre sola es
      // peor que decirlo antes.
      await _abrir(
        tester,
        capacidad: const Capacidad(memoriaMb: 2048, queTanBien: QueTanBien.no),
      );

      expect(find.textContaining('al menos 4 GB'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Bajar la IA'),
            )
            .onPressed,
        isNull,
      );
    });
  });

  group('bajando', () {
    testWidgets('muestra la barra con el porcentaje', (tester) async {
      await _abrir(
        tester,
        descarga: DescargaFalsa(
          pasos: const [
            Descarga(paso: PasoDescarga.bajando, bajados: 40, total: 100),
          ],
        ),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Bajar la IA'));
      await tester.pumpAndSettle();

      final barra = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(barra.value, closeTo(0.4, 0.001));
      expect(find.textContaining('40%'), findsOneWidget);
      expect(find.text('Pausar'), findsOneWidget);
    });

    testWidgets('mientras verifica, no promete un porcentaje', (tester) async {
      // Sacarle la huella a 400 MB son unos segundos: la barra se deja
      // moviéndose para que no parezca que se colgó.
      await _abrir(
        tester,
        descarga: DescargaFalsa(
          pasos: const [
            Descarga(paso: PasoDescarga.verificando, bajados: 100, total: 100),
          ],
        ),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Bajar la IA'));
      await tester.pump();

      expect(find.textContaining('Revisando'), findsOneWidget);
      final barra = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(barra.value, isNull);
    });

    testWidgets('cuando termina, avisa con la ruta del modelo', (tester) async {
      final descarga = DescargaFalsa();
      final listo = await _abrir(tester, descarga: descarga);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Bajar la IA'));
      await tester.pumpAndSettle();

      expect(descarga.bajadas, 1);
      expect(listo.single, descarga.rutaFinal);
    });

    testWidgets('si ya estaba bajado, ni pregunta', (tester) async {
      final descarga = DescargaFalsa(yaBajado: true);

      final listo = await _abrir(tester, descarga: descarga);

      expect(listo.single, descarga.rutaFinal);
      expect(descarga.bajadas, 0);
    });

    testWidgets('lo que quedó a medias se retoma', (tester) async {
      await _abrir(
        tester,
        descarga: DescargaFalsa(aMedias: 50 * 1024 * 1024),
      );

      expect(find.textContaining('bajados de antes'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Seguir bajando'),
        findsOneWidget,
      );
    });
  });

  group('cuando falla', () {
    testWidgets('lo dice y deja reintentar', (tester) async {
      await _abrir(
        tester,
        descarga: DescargaFalsa(
          pasos: const [
            Descarga(
              paso: PasoDescarga.fallo,
              problema: 'El servidor contestó 500. Probá de nuevo más tarde.',
            ),
          ],
        ),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Bajar la IA'));
      await tester.pumpAndSettle();

      expect(find.textContaining('500'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Probar de nuevo'),
        findsOneWidget,
      );
    });

    testWidgets('un archivo que no es el esperado se cuenta', (tester) async {
      // Que se borre y no se use lo prueba descarga_modelo_test.dart; acá lo
      // que importa es que se vea en pantalla.
      await _abrir(
        tester,
        descarga: DescargaFalsa(
          pasos: const [
            Descarga(
              paso: PasoDescarga.fallo,
              problema: 'El archivo que se bajó no es el que esperábamos. '
                  'Se borró; probá de nuevo.',
            ),
          ],
        ),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Bajar la IA'));
      await tester.pumpAndSettle();

      expect(find.textContaining('no es el que esperábamos'), findsOneWidget);
    });
  });
}
