import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/datos/repositorio_percorso.dart';
import 'package:tukyliano/modelos/destino.dart';

/// Los tests de widget corren por defecto en una superficie de 800x600, que es
/// más baja que cualquier celular: el teclado no entra y los toques caen fuera
/// de la pantalla. Esto la deja en un tamaño realista de celular.
void usarPantallaDeCelular(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Vuelve hasta el mapa, que es el inicio, desde donde se esté.
///
/// Dos flechas distintas porque son dos cabeceras distintas: las secciones
/// usan `arrow_back` y la ciudad `arrow_back_rounded`. Buscar solo una
/// dejaba el camino a medio salir.
Future<void> volverAlMapa(WidgetTester tester) async {
  for (var vueltas = 0; vueltas < 6; vueltas++) {
    final flecha = [
      find.byIcon(Icons.arrow_back),
      find.byIcon(Icons.arrow_back_rounded),
    ].where((f) => f.evaluate().isNotEmpty).firstOrNull;
    if (flecha == null) return;
    await tester.tap(flecha);
    await tester.pumpAndSettle();
  }
  fail('No se pudo volver al mapa: la flecha de atrás no lleva a ningún lado');
}

/// Entra a una de las prácticas, salga de donde salga.
///
/// Cuatro están al costado del mapa y se tocan por su dibujo. Gramática y
/// hablar no: viven adentro de la ciudad, abajo de la fila de lecciones,
/// así que primero hay que abrir Palermo.
Future<void> entrarA(WidgetTester tester, Destino destino) async {
  await volverAlMapa(tester);
  if (paraPracticarMas.contains(destino)) {
    await tester.tap(find.text('Palermo'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(destino.etiqueta), 150);
    await tester.tap(find.text(destino.etiqueta));
  } else {
    await tester.tap(find.byTooltip(destino.etiqueta));
  }
  await tester.pumpAndSettle();
}

/// El camino de verdad, leído del archivo en vez del bundle.
///
/// Por qué no del bundle: en un archivo de tests que abre la app más de una
/// vez, la segunda carga de `rootBundle` no termina nunca —el reloj falso de
/// los tests no la deja— y el mapa queda sin ciudades, sin error ni aviso.
/// Costó encontrarlo: el primer test pasaba y el segundo fallaba con "no
/// encuentro Palermo".
///
/// Leyendo el archivo de forma sincrónica se prueba el percorso real igual,
/// que es lo que importa, y sin esa trampa.
RepositorioPercorso caminoDePrueba() => RepositorioPercorso(
  leerAsset: (ruta) async => File(ruta).readAsStringSync(),
);
