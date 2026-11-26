import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/datos/repositorio_percorso.dart';
import 'package:tukyliano/datos/repositorio_racconti.dart';
import 'package:tukyliano/logica/armar_frase.dart';
import 'package:tukyliano/logica/leccion.dart';
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
/// así que primero hay que abrir la primera ciudad del camino, que es la
/// única que arranca desbloqueada.
Future<void> entrarA(WidgetTester tester, Destino destino) async {
  await volverAlMapa(tester);
  if (paraPracticarMas.contains(destino)) {
    await tester.tap(find.text(primeraCiudad));
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

/// La primera ciudad del camino: la única abierta al empezar de cero.
const String primeraCiudad = 'Olbia';

/// Toca el botón grande de abajo de una lección, sea cual sea el que esté.
Future<void> botonDeAbajo(WidgetTester tester) async {
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();
}

/// Contesta bien el paso que está a la vista, si hay algo que contestar.
///
/// Está acá y no en cada test porque lo usan tres archivos, y cada copia
/// se desactualizaba sola al agregar un tipo de paso nuevo.
Future<void> contestarBien(WidgetTester tester, Paso paso) async {
  switch (paso) {
    case ElegirTraduccion(:final correcta):
      // La última: hay palabras que se escriben igual en los dos idiomas
      // —"casa", "la", "un"— y entonces el texto está dos veces, arriba en
      // la tarjeta y abajo en las opciones. La de abajo es la que se toca.
      await tester.tap(find.text(correcta).last);
      await tester.pumpAndSettle();
    case Contestar(:final pregunta):
      await tester.tap(find.text(pregunta.correcta).last);
      await tester.pumpAndSettle();
    case Relacionar(:final pares):
      // first y last porque hay palabras que se escriben igual en los dos
      // idiomas —"casa"— y entonces están en las dos columnas. La
      // izquierda se dibuja primero, así que first es la italiana.
      for (final par in pares) {
        await tester.tap(find.text(par.italiano).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(par.espanol).last);
        await tester.pumpAndSettle();
      }
    case ArmarLaFrase(:final frase, :final fichas):
      for (final palabra in palabrasDeLaFrase(frase.italiano)) {
        await tester.tap(
          find.text(fichas[fichas.indexOf(comoFicha(palabra))]).last,
        );
        await tester.pumpAndSettle();
      }
    case MostrarExplicacion():
    case MostrarPalabra():
    case MostrarFrase():
    case MostrarDialogo():
      break;
  }
}

/// Si el paso tiene algo que contestar, y entonces lleva dos toques:
/// Comprobar y después Seguir.
bool seContesta(Paso paso) =>
    paso is ElegirTraduccion ||
    paso is Contestar ||
    paso is Relacionar ||
    paso is ArmarLaFrase;

/// Juega la lección desde donde esté hasta el paso número [hasta],
/// contestando siempre bien.
Future<void> jugarHasta(
  WidgetTester tester,
  List<Paso> guion,
  int hasta,
) async {
  for (var i = 0; i < hasta; i++) {
    final paso = guion[i];
    await contestarBien(tester, paso);
    await botonDeAbajo(tester);
    if (seContesta(paso)) await botonDeAbajo(tester);
  }
}

/// Los cuentos de verdad, leídos del archivo y no del bundle.
///
/// Por lo mismo que [caminoDePrueba]: con el reloj falso de los tests la
/// carga del bundle no termina y la pantalla se queda en "Cargando
/// cuentos...". Y sin red: el cliente contesta 404 a todo, así que no se
/// busca nada en GitHub.
RepositorioRacconti raccontiDePrueba() => RepositorioRacconti(
  leerAsset: (ruta) async => File(ruta).readAsStringSync(),
  cliente: MockClient((_) async => http.Response('', 404)),
  carpeta: () async => null,
);
