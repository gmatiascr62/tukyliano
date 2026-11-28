// Las seis luces del mapa: cómo se ganan y cómo se pierden.
//
// Es la parte de la app que **saca** cosas —una luz, y después una
// ciudad—, así que es la que más caro paga un error: un castigo cobrado
// de más le borra a alguien una prueba que aprobó de verdad. Por eso se
// mide acá, con el reloj puesto a mano, y no mirando la pantalla.

import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/datos/progreso.dart';
import 'package:tukyliano/logica/luces.dart';
import 'package:tukyliano/modelos/percorso.dart';

Progreso _nuevo() => Progreso(carpeta: () async => null);

Ciudad _ciudad(String id) => Ciudad(
  id: id,
  nombre: id,
  lecciones: [
    for (var i = 1; i <= 10; i++) Leccion(id: '$id-$i', titulo: 'Lección $i'),
    Leccion(id: '$id-prueba', titulo: 'La prueba', esPrueba: true),
  ],
);

final _camino = [_ciudad('olbia'), _ciudad('cagliari'), _ciudad('palermo')];

/// Hace [cuantas] lecciones distintas, que es lo que suma luz.
void _hacer(Progreso progreso, int cuantas, {String ciudad = 'olbia'}) {
  for (var i = 1; i <= cuantas; i++) {
    progreso.termino('$ciudad-$i');
  }
}

void main() {
  group('ganar luces', () {
    test('cada dos lecciones se prende una', () {
      final progreso = _nuevo();
      expect(progreso.luces, 0);

      progreso.termino('olbia-1');
      expect(progreso.luces, 0, reason: 'con una sola todavía no');
      progreso.termino('olbia-2');
      expect(progreso.luces, 1);
      progreso.termino('olbia-3');
      progreso.termino('olbia-4');
      expect(progreso.luces, 2);
    });

    test('seis es el tope: lo que sobra se pierde', () {
      final progreso = _nuevo();
      _hacer(progreso, 10);
      expect(progreso.luces, 5, reason: 'diez lecciones son cinco luces');

      _hacer(progreso, 10, ciudad: 'cagliari');
      expect(progreso.luces, cuantasLuces, reason: 'no pasa de seis');
    });

    test('la misma lección dos veces seguidas no suma', () {
      // Si no, se juntarían las seis luces repitiendo la lección 1.
      final progreso = _nuevo();
      for (var i = 0; i < 10; i++) {
        progreso.termino('olbia-1');
      }

      expect(progreso.luces, 0);
    });

    test('alternando dos lecciones sí suma: repasar es estudiar', () {
      // El que terminó todo el contenido no tiene lecciones nuevas, y
      // tiene que poder mantener las luces repasando.
      final progreso = _nuevo();
      progreso.termino('olbia-1');
      progreso.termino('olbia-2');
      progreso.termino('olbia-1');
      progreso.termino('olbia-2');

      expect(progreso.luces, 2);
    });

    test('la prueba cuenta como una lección más', () {
      final progreso = _nuevo();
      progreso.termino('olbia-10');
      progreso.termino('olbia-prueba');

      expect(progreso.luces, 1);
    });
  });

  group('perder luces', () {
    test('una semana entera sin estudiar apaga una', () {
      final progreso = _nuevo();
      _hacer(progreso, 6); // tres luces
      expect(progreso.luces, 3);

      final enSeisDias = DateTime.now().add(const Duration(days: 6));
      expect(cobrarElOlvido(progreso, _camino, hoy: enSeisDias), 0);
      expect(progreso.luces, 3, reason: 'seis días no es una semana');

      final enSieteDias = DateTime.now().add(const Duration(days: 7));
      cobrarElOlvido(progreso, _camino, hoy: enSieteDias);
      expect(progreso.luces, 2);
    });

    test('tres semanas de una sola vez apagan tres', () {
      // El que vuelve después de un mes tiene que encontrar la cuenta
      // hecha, no una sola semana cobrada por abrir la app una vez.
      final progreso = _nuevo();
      _hacer(progreso, 10);
      _hacer(progreso, 2, ciudad: 'cagliari');
      expect(progreso.luces, cuantasLuces);

      cobrarElOlvido(
        progreso,
        _camino,
        hoy: DateTime.now().add(const Duration(days: 21)),
      );
      expect(progreso.luces, cuantasLuces - 3);
    });

    test('el mismo castigo no se cobra dos veces', () {
      // Sin esto, abrir la app tres veces el mismo día cobraría tres
      // semanas.
      final progreso = _nuevo();
      _hacer(progreso, 6);
      final dentroDeDosSemanas = DateTime.now().add(const Duration(days: 14));

      cobrarElOlvido(progreso, _camino, hoy: dentroDeDosSemanas);
      expect(progreso.luces, 1);
      cobrarElOlvido(progreso, _camino, hoy: dentroDeDosSemanas);
      cobrarElOlvido(progreso, _camino, hoy: dentroDeDosSemanas);
      expect(progreso.luces, 1, reason: 'ya estaba cobrado');
    });

    test('hacer una lección reinicia el reloj', () {
      final progreso = _nuevo();
      _hacer(progreso, 6);
      cobrarElOlvido(
        progreso,
        _camino,
        hoy: DateTime.now().add(const Duration(days: 7)),
      );
      expect(progreso.luces, 2);

      // Vuelve a estudiar: desde acá empieza a contar de nuevo.
      progreso.termino('olbia-7');
      cobrarElOlvido(
        progreso,
        _camino,
        hoy: DateTime.now().add(const Duration(days: 6)),
      );
      expect(progreso.luces, 2, reason: 'no pasó una semana desde la última');
    });

    test('sin ninguna lección hecha no se castiga nada', () {
      // El que instaló la app y no entró en un mes no perdió nada: no
      // había empezado.
      final progreso = _nuevo();

      cobrarElOlvido(
        progreso,
        _camino,
        hoy: DateTime.now().add(const Duration(days: 60)),
      );
      expect(progreso.luces, 0);
      expect(progreso.hizo('olbia-prueba'), isFalse);
    });
  });

  group('retroceder de ciudad', () {
    test('sin luces, la semana se lleva la prueba de la última ciudad', () {
      final progreso = _nuevo();
      _hacer(progreso, 10);
      progreso.termino('olbia-prueba');
      expect(progreso.hizo('olbia-prueba'), isTrue);

      // Siete semanas: seis se comen las luces y la séptima, la ciudad.
      final retrocedidas = cobrarElOlvido(
        progreso,
        _camino,
        hoy: DateTime.now().add(const Duration(days: 7 * 7)),
      );

      expect(retrocedidas, 1);
      expect(progreso.luces, 0);
      expect(
        progreso.hizo('olbia-prueba'),
        isFalse,
        reason: 'hay que darla de nuevo para volver a abrir Cagliari',
      );
      expect(
        progreso.hizo('olbia-10'),
        isTrue,
        reason: 'las lecciones quedan hechas: se pierde la prueba, no todo',
      );
    });

    test('retrocede de a una por semana, de la última para atrás', () {
      final progreso = _nuevo();
      progreso.termino('olbia-prueba');
      progreso.termino('cagliari-prueba');
      // Dos lecciones contadas, así que hay una luz prendida: la primera
      // semana se la lleva, y recién la segunda y la tercera retroceden.
      expect(progreso.luces, 1);

      final retrocedidas = cobrarElOlvido(
        progreso,
        _camino,
        hoy: DateTime.now().add(const Duration(days: 21)),
      );

      expect(retrocedidas, 2);
      expect(progreso.hizo('cagliari-prueba'), isFalse);
      expect(progreso.hizo('olbia-prueba'), isFalse);
    });

    test('en la primera ciudad no hay nada atrás que perder', () {
      // Sin ninguna prueba aprobada no hay ciudad que sacar, y el que
      // recién llega no tiene que encontrarse con un castigo.
      final progreso = _nuevo();
      _hacer(progreso, 2);

      final retrocedidas = cobrarElOlvido(
        progreso,
        _camino,
        hoy: DateTime.now().add(const Duration(days: 60)),
      );

      expect(retrocedidas, 0);
      expect(progreso.luces, 0);
    });
  });

  group('el color y la palabra', () {
    test('las dos primeras son rojas, las dos del medio amarillas, las dos '
        'últimas verdes', () {
      expect(
        [for (var i = 0; i < cuantasLuces; i++) animoDeLaLuz(i)],
        [
          Animo.cuidado,
          Animo.cuidado,
          Animo.seguilo,
          Animo.seguilo,
          Animo.bien,
          Animo.bien,
        ],
      );
    });

    test('el color es el de la última luz prendida', () {
      expect(animoDe(0), Animo.cuidado);
      expect(animoDe(2), Animo.cuidado);
      expect(animoDe(3), Animo.seguilo);
      expect(animoDe(4), Animo.seguilo);
      expect(animoDe(5), Animo.bien);
      expect(animoDe(6), Animo.bien);
    });

    test('el renglón nombra la ciudad que está en juego', () {
      // "Cuidado" no explica nada. Lo que de verdad pasa es que la
      // semana que viene se deshace la prueba de Olbia y Cagliari se
      // cierra, así que eso es lo que dice.
      expect(loQueEstaEnJuego(1, 'Cagliari'), 'Estás por perder Cagliari');
      expect(loQueEstaEnJuego(3, 'Cagliari'), 'Cagliari está a salvo');
      expect(loQueEstaEnJuego(6, 'Cagliari'), 'Vas firme');
    });

    test('sin ninguna ciudad ganada no se nombra ninguna', () {
      // El que recién empieza no tiene nada que perder, y un cartel que
      // le diga que está por perder algo sería mentira.
      expect(loQueEstaEnJuego(0, ''), 'Cuidado');
      expect(loQueEstaEnJuego(3, ''), 'Vas bien');
      expect(loQueEstaEnJuego(6, ''), 'Vas firme');
    });

    test('la ciudad en juego es la que se cierra, no la que se deshace', () {
      // Se deshace la prueba de Olbia, pero la que se pierde —la que
      // deja de poder abrirse— es Cagliari, la de más adelante.
      final progreso = _nuevo()..termino('olbia-prueba');
      expect(ciudadEnRiesgo(_camino, progreso), 'cagliari');

      progreso.termino('cagliari-prueba');
      expect(ciudadEnRiesgo(_camino, progreso), 'palermo');
    });

    test('sin pruebas aprobadas no hay ciudad en juego', () {
      expect(ciudadEnRiesgo(_camino, _nuevo()), '');
    });

    test('en la última ciudad del camino se pierde ella misma', () {
      // No hay ninguna adelante que cerrar, así que lo que está en
      // juego es la que se estaba haciendo.
      final progreso = _nuevo()
        ..termino('olbia-prueba')
        ..termino('cagliari-prueba')
        ..termino('palermo-prueba');
      expect(ciudadEnRiesgo(_camino, progreso), 'palermo');
    });
  });
}
