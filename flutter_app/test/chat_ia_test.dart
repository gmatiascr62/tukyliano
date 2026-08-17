import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/ia/chat.dart';

/// El texto de un turno del pedido a la API.
String _texto(Map<String, dynamic> turno) =>
    ((turno['parts'] as List).first as Map)['text'] as String;

void main() {
  group('las almohadillas', () {
    test('una palabra sola es un pedido de traducción', () {
      expect(pedidosDeTraduccion('#manteca#'), ['manteca']);
    });

    test('también admite una frase entera', () {
      expect(pedidosDeTraduccion('#como estás?#'), ['como estás?']);
    });

    test('reconoce el pedido en medio de la charla', () {
      expect(
        pedidosDeTraduccion('mi serve la #manteca# per la torta'),
        ['manteca'],
      );
    });

    test('varios pedidos en el mismo mensaje', () {
      expect(pedidosDeTraduccion('#manteca# y #pan#'), ['manteca', 'pan']);
    });

    test('sin almohadillas no hay ningún pedido', () {
      expect(pedidosDeTraduccion('ciao, come stai?'), isEmpty);
    });

    test('una almohadilla sin cerrar todavía no es un pedido', () {
      // Pasa mientras se escribe: se tocó la tecla y falta la palabra.
      expect(pedidosDeTraduccion('#mante'), isEmpty);
    });

    test('el texto vacío entre almohadillas no cuenta', () {
      expect(pedidosDeTraduccion('##'), isEmpty);
    });

    test('partir marca solo lo que está entre almohadillas', () {
      expect(partirPorMarcas('quiero #manteca# fresca'), [
        (texto: 'quiero ', marcada: false),
        (texto: '#manteca#', marcada: true),
        (texto: ' fresca', marcada: false),
      ]);
    });

    test('partir no pierde ni una letra del mensaje', () {
      // La pantalla dibuja estos trozos: si perdiera algo, el mensaje se vería
      // distinto de como se escribió. La almohadilla a medio escribir incluida.
      for (final texto in [
        'quiero #manteca# y #pan#',
        '#man',
        'sin nada',
        '##',
        '#manteca# = #burro#\nChe cucini?',
      ]) {
        expect(partirPorMarcas(texto).map((t) => t.texto).join(), texto);
      }
    });

    test('para el audio se sacan las almohadillas', () {
      // Si no, el motor pronunciaría el símbolo en vez de leer la palabra.
      expect(sinMarcas('#manteca# = #burro#'), 'manteca = burro');
      expect(sinMarcas('Ciao! Come stai?'), 'Ciao! Come stai?');
    });
  });

  group('el mensaje que se le manda a la IA', () {
    test('sin pedidos va tal cual se escribió', () {
      expect(textoParaLaIa('ciao, sto bene'), 'ciao, sto bene');
    });

    test('con un pedido se le recuerda el formato de la respuesta', () {
      final texto = textoParaLaIa('mi serve la #manteca#');

      expect(texto, startsWith('mi serve la #manteca#'));
      expect(texto, contains('#manteca# = #(traducción)#'));
    });

    test('con varios pedidos los nombra a todos', () {
      final texto = textoParaLaIa('#manteca# y #pan#');

      expect(texto, contains('#manteca# = #(traducción)#'));
      expect(texto, contains('#pan# = #(traducción)#'));
    });
  });

  group('la conversación', () {
    test('arranca con el saludo puesto, sin gastar un pedido', () {
      final charla = Conversacion();

      expect(charla.mensajes.length, 1);
      expect(charla.mensajes.single.quien, Quien.ia);
      expect(charla.mensajes.single.texto, saludoInicial);
    });

    test('el primer pedido lleva las instrucciones y el saludo', () {
      final charla = Conversacion()..agregar(const Mensaje.mia('ciao'));

      final turnos = charla.contenidos();

      expect(turnos.length, 3);
      expect(turnos[0]['role'], 'user');
      expect(_texto(turnos[0]), promptDeChat);
      expect(turnos[1]['role'], 'model');
      expect(_texto(turnos[1]), saludoInicial);
      expect(turnos[2]['role'], 'user');
      expect(_texto(turnos[2]), 'ciao');
    });

    test('la memoria son los turnos anteriores, en orden', () {
      final charla = Conversacion()
        ..agregar(const Mensaje.mia('mi chiamo Matías'))
        ..agregar(const Mensaje.deLaIa('Piacere! Dove abiti?'))
        ..agregar(const Mensaje.mia('abito a Buenos Aires'));

      final turnos = charla.contenidos();

      expect(turnos.map((t) => t['role']).toList(),
          ['user', 'model', 'user', 'model', 'user']);
      expect(_texto(turnos[2]), 'mi chiamo Matías');
      expect(_texto(turnos[3]), 'Piacere! Dove abiti?');
      expect(_texto(turnos[4]), 'abito a Buenos Aires');
    });

    test('los avisos de la app no se le mandan a la IA', () {
      // Un cartel de "no hay internet" no es parte de la charla: si se
      // mandara, la IA lo leería como si el alumno lo hubiera escrito.
      final charla = Conversacion()
        ..agregar(const Mensaje.mia('ciao'))
        ..agregar(const Mensaje.aviso('No se pudo hablar con la IA.'));

      final turnos = charla.contenidos();

      expect(turnos.length, 3);
      expect(_texto(turnos[2]), 'ciao');
    });

    test('el recordatorio de traducción va solo en el último mensaje', () {
      final charla = Conversacion()
        ..agregar(const Mensaje.mia('#manteca#'))
        ..agregar(const Mensaje.deLaIa('#manteca# = #burro#'))
        ..agregar(const Mensaje.mia('#pan#'));

      final turnos = charla.contenidos();

      expect(_texto(turnos[2]), '#manteca#');
      expect(_texto(turnos[4]), contains('Recordá'));
    });
  });

  group('las instrucciones', () {
    test('explican el formato de las traducciones con el ejemplo pedido', () {
      expect(promptDeChat, contains('#manteca# = #burro#'));
      expect(promptDeChat, contains('#como estas?#'));
    });

    test('piden italiano simple y respuestas cortas', () {
      expect(promptDeChat, contains('italiano simple'));
      expect(promptDeChat, contains('Correzione:'));
    });

    test('no piden markdown, que se leería en voz alta', () {
      expect(promptDeChat, contains('No uses markdown'));
    });
  });

  test('el teclado del chat trae la almohadilla', () {
    // Sin esta tecla no habría forma de pedir una traducción.
    expect(teclasDelChat, contains('#'));
  });

  test('no hay ninguna clave de la API en el código', () {
    // El repo es público y Google revoca las claves que encuentra publicadas:
    // ya pasó una vez. La clave se pega en el celular y vive solo ahí.
    final conClave = [
      for (final archivo in Directory('lib').listSync(recursive: true))
        if (archivo is File &&
            archivo.path.endsWith('.dart') &&
            RegExp(r'AIza[0-9A-Za-z_\-]{10,}')
                .hasMatch(archivo.readAsStringSync()))
          archivo.path,
    ];

    expect(conClave, isEmpty);
  });
}
