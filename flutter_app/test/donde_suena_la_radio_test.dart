// A qué dirección se le pide el audio de una emisora que reparte desde
// varios nodos.
//
// Lo que se prueba acá es sobre todo lo que pasa cuando algo sale mal,
// porque el caso feliz es de una línea y los otros son los que dejan la
// radio muda. La regla es una sola: pase lo que pase hay que terminar con
// una dirección que suene, y si no se sabe cuál es la de hoy, se usa la de
// siempre.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/datos/donde_suena_la_radio.dart';
import 'package:tukyliano/modelos/radio_italiana.dart';

const _elBalanceador =
    'https://samcloud.spacial.com/api/listen?sid=79541&m=sc&rid=156616';
const _laDeSiempre = 'https://24293.live.streamtheworld.com/SAM01AAC222_SC';

RadioItaliana _laRadio({String balanceador = _elBalanceador}) => RadioItaliana(
      id: 'senti-chi-parla',
      nombre: 'Radio Senti Chi Parla',
      que: '',
      ojo: '',
      stream: _laDeSiempre,
      balanceador: balanceador,
      sitio: '',
      sostener: '',
      quien: '',
    );

/// Un balanceador que contesta lo que se le diga.
DondeSuenaLaRadio _queContesta(
  int estado,
  Map<String, String> encabezados, {
  Duration? tardando,
}) =>
    DondeSuenaLaRadio(
      cuantoEspera: const Duration(milliseconds: 80),
      cliente: MockClient.streaming((_, _) async {
        if (tardando != null) await Future<void>.delayed(tardando);
        return http.StreamedResponse(
          const Stream<List<int>>.empty(),
          estado,
          headers: encabezados,
        );
      }),
    );

void main() {
  test('usa el nodo que dice el balanceador', () async {
    final donde = _queContesta(302, {
      'location': 'http://15113.live.streamtheworld.com/SAM01AAC222_SC',
    });

    expect(await donde.de(_laRadio()),
        'https://15113.live.streamtheworld.com/SAM01AAC222_SC');
  });

  test('le cambia el http por https', () async {
    // El balanceador siempre contesta http, y así no sirve: Android bloquea
    // el tráfico sin cifrar. Los nodos hablan https igual —se probó con el
    // 26343 y el 15113 desde un celular— así que se les pide por https.
    final donde = _queContesta(302, {
      'location': 'http://26343.live.streamtheworld.com/SAM01AAC222_SC',
    });

    final cual = await donde.de(_laRadio());
    expect(cual, startsWith('https://'));
    expect(cual, isNot(contains('http://')));
  });

  test('si ya viene por https no lo toca', () async {
    final donde = _queContesta(302, {
      'location': 'https://99999.live.streamtheworld.com/SAM01AAC222_SC',
    });

    expect(await donde.de(_laRadio()),
        'https://99999.live.streamtheworld.com/SAM01AAC222_SC');
  });

  group('cuando no se puede saber cuál es el nodo de hoy', () {
    test('sin internet, suena por la de siempre', () async {
      final donde = DondeSuenaLaRadio(
        cliente: MockClient((_) async => throw const SocketException('')),
      );

      expect(await donde.de(_laRadio()), _laDeSiempre);
    });

    test('si el balanceador tarda, no se espera', () async {
      // Esto corre entre que la persona toca play y empieza a sonar. Más
      // vale sonar por la dirección vieja que dejarla mirando el botón.
      final donde = _queContesta(
        302,
        {'location': 'http://15113.live.streamtheworld.com/SAM01AAC222_SC'},
        tardando: const Duration(seconds: 3),
      );

      expect(await donde.de(_laRadio()), _laDeSiempre);
    });

    test('si contesta 200 en vez de un redirect, la de siempre', () async {
      expect(await _queContesta(200, const {}).de(_laRadio()), _laDeSiempre);
    });

    test('si contesta un error, la de siempre', () async {
      expect(await _queContesta(500, const {}).de(_laRadio()), _laDeSiempre);
    });

    test('si redirige sin decir a dónde, la de siempre', () async {
      expect(await _queContesta(302, const {}).de(_laRadio()), _laDeSiempre);
    });

    test('si apunta a cualquier cosa, la de siempre', () async {
      // Un esquema que no es http ni https no se reproduce, y uno sin
      // servidor tampoco. Mejor la vieja que una que no abre.
      for (final basura in ['javascript:alert(1)', 'file:///etc/passwd',
        '/SAM01AAC222_SC', 'no es una dirección']) {
        expect(await _queContesta(302, {'location': basura}).de(_laRadio()),
            _laDeSiempre,
            reason: basura);
      }
    });
  });

  test('una emisora sin balanceador no pregunta nada', () async {
    // Las que transmiten siempre desde el mismo lugar no tienen por qué
    // pagar una consulta de red antes de sonar.
    var preguntaron = false;
    final donde = DondeSuenaLaRadio(cliente: MockClient((_) async {
      preguntaron = true;
      return http.Response('', 302);
    }));

    expect(await donde.de(_laRadio(balanceador: '')), _laDeSiempre);
    expect(preguntaron, isFalse);
  });
}
