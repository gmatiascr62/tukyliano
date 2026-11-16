// El diccionario de respaldo, del lado de la app.
//
// Lo que importa probar acá no es que traduzca: es **cuándo sale a internet y
// cuándo no**. Si eso se rompe, la traducción aparece igual y nadie lo nota,
// pero se paga: una ida al servidor por cada toque, en vez de una por palabra.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/datos/buscador_de_palabras.dart';
import 'package:tukyliano/datos/quien_soy.dart';
import 'package:tukyliano/ia/servidor.dart';
import 'package:tukyliano/modelos/diccionario.dart';

const _chico = Diccionario(
  italiano: {
    'finestra': ['ventana'],
    'acqua': ['agua'],
  },
);

/// Anota qué se le pidió al servidor y contesta lo que se le diga.
class _Espia {
  final List<Map<String, dynamic>> pedidos = [];

  Servidor servidor({List<String> es = const [], String base = ''}) {
    return Servidor(
      url: 'https://servidor-de-mentira',
      cliente: MockClient((pedido) async {
        pedidos.add(jsonDecode(pedido.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode({'palabra': 'x', 'es': es, 'base': base}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  }
}

BuscadorDePalabras _buscador(Servidor servidor) => BuscadorDePalabras(
      servidor: servidor,
      // Sin carpeta donde escribir, QuienSoy igual inventa un número para
      // esta sesión. Así el test no toca el disco.
      quienSoy: QuienSoy(carpeta: () async => null),
      // Sin esperar de verdad entre intentos: el test prueba que se
      // reintente, no el reloj.
      esperar: (_) async {},
    );

void main() {
  test('lo que está en el diccionario no sale a internet', () async {
    final espia = _Espia();
    final buscador = _buscador(espia.servidor(es: ['no debería pedirse']));

    final hallada = await buscador.buscar(_chico, 'finestra');

    expect(hallada!.comoSeDice, 'ventana');
    expect(espia.pedidos, isEmpty, reason: 'fue al servidor sin necesidad');
  });

  test('lo que no está se le pregunta al servidor', () async {
    final espia = _Espia();
    final buscador = _buscador(espia.servidor(es: ['velita', 'luz baja']));

    final hallada = await buscador.buscar(_chico, 'lumicino');

    expect(hallada, isNotNull);
    expect(hallada!.comoSeDice, 'velita, luz baja');
    expect(espia.pedidos.single['palabra'], 'lumicino');
  });

  test('la misma palabra se pide UNA vez por sesión', () async {
    final espia = _Espia();
    final buscador = _buscador(espia.servidor(es: ['velita']));

    await buscador.buscar(_chico, 'lumicino');
    await buscador.buscar(_chico, 'Lumicino');
    await buscador.buscar(_chico, 'lumicino');

    expect(espia.pedidos.length, 1);
  });

  test('una que nadie sabe tampoco se vuelve a pedir', () async {
    // Sin esto, una palabra que no existe cuesta una ida al servidor cada
    // vez que alguien la toca, y nunca va a dar nada.
    final espia = _Espia();
    final buscador = _buscador(espia.servidor());

    expect(await buscador.buscar(_chico, 'chirimbolo'), isNull);
    expect(await buscador.buscar(_chico, 'chirimbolo'), isNull);

    expect(espia.pedidos.length, 1);
  });

  test('se manda el renglón, que es lo que desambigua', () async {
    // "lumicino" solo es "lucecita". En "ridotto al lumicino" es "en las
    // últimas", que es lo que quiere saber el que lo tocó.
    final espia = _Espia();
    final buscador = _buscador(espia.servidor(es: ['en las últimas']));

    await buscador.buscar(_chico, 'lumicino',
        donde: 'Un Lupo già ridotto al lumicino');

    expect(espia.pedidos.single['donde'], contains('ridotto al lumicino'));
  });

  test('dice de qué palabra viene, si el servidor lo dijo', () async {
    final espia = _Espia();
    final buscador = _buscador(espia.servidor(es: ['abejas'], base: 'pecchia'));

    final hallada = await buscador.buscar(_chico, 'pecchie');

    expect(hallada!.vieneDe, 'pecchia');
  });

  test('sin internet no se rompe nada: contesta que no está', () async {
    final buscador = _buscador(Servidor(
      url: 'https://servidor-de-mentira',
      cliente: MockClient((_) async => throw Exception('sin señal')),
    ));

    expect(await buscador.buscar(_chico, 'lumicino'), isNull);
    // Y lo que sí está sigue saliendo igual, que es lo importante.
    expect((await buscador.buscar(_chico, 'acqua'))!.comoSeDice, 'agua');
  });

  test('si la IA todavía está pensando, se vuelve a preguntar', () async {
    // "Todavía no" no es "no existe". El servidor le contesta rápido al que
    // pregunta y sigue esperando a la IA por su cuenta; cuando llega, la
    // guarda. La segunda pregunta cae en la base, no en la IA.
    //
    // Sin esto, el primero que busca una palabra casi nunca la recibe,
    // aunque la palabra haya llegado al servidor un segundo después.
    var cuantas = 0;
    final buscador = _buscador(Servidor(
      url: 'https://servidor-de-mentira',
      cliente: MockClient((_) async {
        cuantas++;
        final cuerpo = cuantas == 1
            ? {'es': [], 'base': '', 'porQue': 'tardo'}
            : {'es': ['morfar'], 'base': ''};
        return http.Response(
          jsonEncode(cuerpo),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    ));

    final hallada = await buscador.buscar(_chico, 'sbasoffiare');

    expect(hallada, isNotNull);
    expect(hallada!.comoSeDice, 'morfar');
    expect(cuantas, 2);
  });

  test('si en el segundo intento tampoco está, se deja de insistir', () async {
    var cuantas = 0;
    final buscador = _buscador(Servidor(
      url: 'https://servidor-de-mentira',
      cliente: MockClient((_) async {
        cuantas++;
        return http.Response(
          jsonEncode({'es': [], 'base': '', 'porQue': 'tardo'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    ));

    expect(await buscador.buscar(_chico, 'chirimbolo'), isNull);
    expect(cuantas, 2, reason: 'insistió de más');
  });

  test('sabe cuándo puede contestar sin internet', () async {
    // Sirve para no mostrar "buscando…" un instante cuando la respuesta ya
    // está acá: ese parpadeo se nota.
    final espia = _Espia();
    final buscador = _buscador(espia.servidor(es: ['velita']));

    expect(buscador.laSabeSinInternet(_chico, 'acqua'), isTrue);
    expect(buscador.laSabeSinInternet(_chico, 'lumicino'), isFalse);

    await buscador.buscar(_chico, 'lumicino');
    expect(buscador.laSabeSinInternet(_chico, 'lumicino'), isTrue);
  });
}
