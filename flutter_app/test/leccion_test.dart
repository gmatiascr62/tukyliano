// El orden de los pasos de una lección.
//
// Lo que hay que cuidar acá es una sola regla, y es la que hace que una
// lección enseñe en vez de tomar examen: nada se pregunta antes de haberse
// mostrado. Mirando la pantalla no se ve —hay que llegar al paso 14 para
// darse cuenta—, así que se mira acá.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/logica/armar_frase.dart';
import 'package:tukyliano/logica/leccion.dart';
import 'package:tukyliano/modelos/percorso.dart';

PalabraDeLeccion _p(String it, String es) =>
    PalabraDeLeccion(italiano: it, espanol: es);

FraseDeLeccion _f(String it, String es) =>
    FraseDeLeccion(italiano: it, espanol: es);

final _palermo1 = Leccion(
  id: 'palermo-1',
  titulo: 'Il gatto è in cucina',
  palabras: [
    _p('il', 'el'),
    _p('la', 'la'),
    _p('un', 'un'),
    _p('è', 'es, está'),
    _p('in', 'en'),
    _p('gatto', 'gato'),
    _p('cucina', 'cocina'),
    _p('casa', 'casa'),
  ],
  frases: [
    _f('Il gatto è in cucina.', 'El gato está en la cocina.'),
    _f('Il gatto è in casa.', 'El gato está en casa.'),
  ],
);

void main() {
  test('nada se pregunta antes de haberse mostrado', () {
    // Se recorre la lección entera llevando la cuenta de lo que ya se vio.
    // Con varias semillas, porque adentro hay mezclas.
    for (var semilla = 0; semilla < 20; semilla++) {
      final mostradas = <String>{};
      final frasesMostradas = <String>{};

      for (final paso in pasosDe(_palermo1, azar: Random(semilla))) {
        switch (paso) {
          case MostrarPalabra(:final palabra):
            mostradas.add(palabra.italiano);
          case MostrarFrase(:final frase):
            frasesMostradas.add(frase.italiano);
          case ElegirTraduccion(:final palabra):
            expect(
              mostradas,
              contains(palabra.italiano),
              reason:
                  'semilla $semilla: se pregunta "${palabra.italiano}" '
                  'antes de mostrarla',
            );
          case ArmarLaFrase(:final frase):
            expect(
              frasesMostradas,
              contains(frase.italiano),
              reason: 'semilla $semilla: se arma una frase sin mostrarla',
            );
          case MostrarExplicacion():
          case MostrarDialogo():
          case Contestar():
          case Relacionar():
            break;
        }
      }
    }
  });

  test('cada palabra se muestra una vez y se pregunta una vez', () {
    final pasos = pasosDe(_palermo1, azar: Random(1));

    final mostradas = [
      for (final paso in pasos)
        if (paso is MostrarPalabra) paso.palabra.italiano,
    ];
    final preguntadas = [
      for (final paso in pasos)
        if (paso is ElegirTraduccion) paso.palabra.italiano,
    ];

    final todas = _palermo1.palabras.map((p) => p.italiano).toList();
    expect(mostradas, todas, reason: 'se muestran en el orden del archivo');
    expect(preguntadas.toSet(), todas.toSet());
    expect(preguntadas.length, todas.length, reason: 'ninguna repetida');
  });

  test('se pregunta de a tandas cortas, no las ocho juntas al final', () {
    // Mostrar las ocho y recién después preguntarlas es pedirle que se
    // acuerde de ocho cosas. El test mira que entre que una palabra se
    // muestra y se pregunta no pasen más de una tanda de pasos.
    final pasos = pasosDe(_palermo1, azar: Random(2));

    for (final palabra in _palermo1.palabras) {
      final seMostro = pasos.indexWhere(
        (p) => p is MostrarPalabra && p.palabra.italiano == palabra.italiano,
      );
      final sePregunto = pasos.indexWhere(
        (p) => p is ElegirTraduccion && p.palabra.italiano == palabra.italiano,
      );
      expect(
        sePregunto - seMostro,
        allOf(greaterThan(0), lessThanOrEqualTo(palabrasPorTanda * 2)),
        reason: palabra.italiano,
      );
    }
  });

  test('las opciones son cuatro, distintas, y una es la correcta', () {
    for (var semilla = 0; semilla < 20; semilla++) {
      for (final paso in pasosDe(_palermo1, azar: Random(semilla))) {
        if (paso is! ElegirTraduccion) continue;
        expect(paso.opciones.length, cuantasOpciones);
        expect(
          paso.opciones.toSet().length,
          cuantasOpciones,
          reason: 'repetidas: ${paso.opciones}',
        );
        expect(paso.opciones, contains(paso.correcta));
      }
    }
  });

  test('con pocas palabras las opciones se completan con relleno', () {
    // Una lección de dos palabras no tiene con qué llenar cuatro opciones.
    final chica = Leccion(
      id: 'x',
      titulo: 'x',
      palabras: [_p('sì', 'sí'), _p('no', 'no')],
    );

    for (final paso in pasosDe(chica, azar: Random(3))) {
      if (paso is! ElegirTraduccion) continue;
      expect(paso.opciones.length, cuantasOpciones);
      expect(paso.opciones.toSet().length, cuantasOpciones);
    }
  });

  test('las fichas para armar alcanzan para la frase entera', () {
    for (var semilla = 0; semilla < 20; semilla++) {
      for (final paso in pasosDe(_palermo1, azar: Random(semilla))) {
        if (paso is! ArmarLaFrase) continue;
        final faltan = [
          for (final palabra in palabrasDeLaFrase(paso.frase.italiano))
            if (!paso.fichas.contains(comoFicha(palabra))) palabra,
        ];
        expect(faltan, isEmpty, reason: 'sin ficha para: $faltan');
        expect(
          paso.fichas.length,
          greaterThan(palabrasDeLaFrase(paso.frase.italiano).length),
          reason: 'sin fichas de más el ejercicio se resuelve solo',
        );
      }
    }
  });

  test('el relacionar no deja ninguna traducción frente a su palabra', () {
    // Mirado renderizado salió una pantalla con las cuatro alineadas:
    // amico-amigo, giorno-día, gelato-helado, ciao-hola, una debajo de
    // la otra. Así el ejercicio se resuelve sin leer nada.
    for (var semilla = 0; semilla < 50; semilla++) {
      for (final paso in pasosDe(_palermo1, azar: Random(semilla))) {
        if (paso is! Relacionar) continue;
        expect(
          hayAlgunaEnLinea(paso.pares, paso.traducciones),
          isFalse,
          reason:
              'semilla $semilla: '
              '${paso.pares.map((p) => p.italiano)} vs ${paso.traducciones}',
        );
        expect(
          paso.traducciones.toSet(),
          paso.pares.map((p) => p.espanol).toSet(),
          reason: 'están las cuatro traducciones y ninguna de más',
        );
      }
    }
  });

  test('la lección del cuento no genera ningún paso', () {
    // No enseña palabras: manda a leer. La pantalla ni se abre, lleva a
    // Racconti, y esto deja escrito que acá no hay nada que hacer.
    const cuento = Leccion(id: 'p5', titulo: 'x', racconto: 'il-gatto');
    expect(pasosDe(cuento), isEmpty);
  });

  test('una lección larga no arma las cinco frases', () {
    final larga = Leccion(
      id: 'p4',
      titulo: 'x',
      palabras: [_p('va', 'va')],
      frases: [
        for (var i = 0; i < 5; i++) _f('Il gatto va $i.', 'El gato va $i.'),
      ],
    );

    final pasos = pasosDe(larga, azar: Random(4));
    expect(pasos.whereType<MostrarFrase>().length, 5);
    expect(pasos.whereType<ArmarLaFrase>().length, frasesParaArmar);
  });
}
