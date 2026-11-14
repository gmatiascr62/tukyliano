import 'dart:io';
import 'dart:math';

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

  group('pedir solo la traducción', () {
    test('una palabra sola entre almohadillas es solo un pedido', () {
      expect(esSoloTraduccion('#manteca#'), isTrue);
    });

    test('una frase sola entre almohadillas también', () {
      expect(esSoloTraduccion('#como estás?#'), isTrue);
    });

    test('varios pedidos pegados siguen siendo solo un pedido', () {
      // Los espacios y los signos de afuera no son charla.
      expect(esSoloTraduccion('#manteca# #pan#'), isTrue);
      expect(esSoloTraduccion('  #manteca# , #pan# ?'), isTrue);
    });

    test('con algo escrito afuera es charla, no un pedido suelto', () {
      expect(esSoloTraduccion('mi serve la #manteca#'), isFalse);
    });

    test('sin almohadillas no es un pedido', () {
      expect(esSoloTraduccion('ciao, come stai?'), isFalse);
      expect(esSoloTraduccion('#mante'), isFalse);
    });

  });

  group('la corrección', () {
    test('la que repite la frase tal cual se escribió no se muestra', () {
      // Es el caso que apareció practicando: "io vado al lavoro" está bien y
      // la corrección decía exactamente lo mismo.
      const contestado = 'Correzione: io vado al lavoro\n'
          'Lavori sempre così presto la mattina?';

      expect(
        sinCorreccionRepetida(contestado, 'io vado al lavoro'),
        'Lavori sempre così presto la mattina?',
      );
    });

    test('tampoco si lo único que cambió son mayúsculas o signos', () {
      const contestado = 'Correzione: Io vado al lavoro.\nChe lavoro fai?';

      expect(
        sinCorreccionRepetida(contestado, 'io vado al lavoro'),
        'Che lavoro fai?',
      );
    });

    test('la corrección de verdad se muestra', () {
      const contestado = 'Correzione: io vado al lavoro\nChe lavoro fai?';

      // Acá sí corrigió: el alumno había escrito el verbo mal.
      expect(
        sinCorreccionRepetida(contestado, 'io ando al lavoro'),
        contestado,
      );
    });

    test('un acento que falta es una corrección de verdad', () {
      // Si se compararan las frases sin acentos, esta se perdería, y es
      // justamente una de las que hay que mostrar.
      const contestado = 'Correzione: perché vai al lavoro?\nE tu?';

      expect(
        sinCorreccionRepetida(contestado, 'perche vai al lavoro?'),
        contestado,
      );
    });

    test('un apóstrofo que falta también', () {
      const contestado = "Correzione: bevo l'acqua\nCosa mangi?";

      expect(sinCorreccionRepetida(contestado, 'bevo lacqua'), contestado);
    });

    test('una respuesta sin corrección queda igual', () {
      const contestado = 'Bene! Lavori sempre così presto?';

      expect(sinCorreccionRepetida(contestado, 'io vado al lavoro'), contestado);
    });

    test('si no queda nada se muestra la respuesta entera', () {
      // Antes una corrección al pedo que una burbuja vacía.
      const contestado = 'Correzione: io vado al lavoro';

      expect(sinCorreccionRepetida(contestado, 'io vado al lavoro'), contestado);
    });

    test('la marca se reconoce con cualquier mayúscula', () {
      const contestado = 'correzione : io vado al lavoro\nE tu?';

      expect(sinCorreccionRepetida(contestado, 'io vado al lavoro'), 'E tu?');
    });
  });

  group('el mensaje que se le manda a la IA', () {
    test('sin almohadillas va tal cual se escribió', () {
      expect(textoParaLaIa('ciao, sto bene'), 'ciao, sto bene');
    });

    test('las almohadillas se sacan antes de mandarlo', () {
      // Las traducciones las contesta el diccionario de la app, así que la IA
      // no tiene por qué enterarse de que hubo un pedido: ve una frase normal
      // y sigue la charla. Antes tres de las nueve reglas del prompt eran
      // sobre esto, y aun así se equivocaba.
      expect(textoParaLaIa('mi serve la #manteca#'), 'mi serve la manteca');
      expect(textoParaLaIa('#manteca# y #pan#'), 'manteca y pan');
    });
  });

  group('la conversación', () {
    test('arranca con el saludo puesto, sin gastar un pedido', () {
      final charla = Conversacion();

      expect(charla.mensajes.length, 1);
      expect(charla.mensajes.single.quien, Quien.ia);
      expect(charla.mensajes.single.texto, charla.saludo);
      expect(saludosIniciales, contains(charla.saludo));
    });

    test('cada charla puede arrancar con otro saludo', () {
      // Con uno solo, todas las charlas empezaban igual y terminaban hablando
      // siempre de lo mismo.
      final salidos = {
        for (var semilla = 0; semilla < 30; semilla++)
          Conversacion(azar: Random(semilla)).saludo,
      };

      expect(salidos.length, greaterThan(5));
    });

    test('el saludo que se le pasa es el que arranca la charla', () {
      final charla = Conversacion(saludo: 'Ciao! Che musica ascolti?');

      expect(charla.mensajes.single.texto, 'Ciao! Che musica ascolti?');
    });

    test('el primer pedido lleva las instrucciones y el saludo', () {
      final charla = Conversacion()..agregar(const Mensaje.mia('ciao'));

      final turnos = charla.contenidos();

      expect(turnos.length, 3);
      expect(turnos[0]['role'], 'user');
      expect(_texto(turnos[0]), promptDeChat);
      expect(turnos[1]['role'], 'model');
      expect(_texto(turnos[1]), charla.saludo);
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

    test('ir al diccionario no entra en lo que la IA recuerda', () {
      // Buscar una palabra no es charlar. Si entrara en el historial, la IA
      // creería que se habló de eso, o copiaría el formato con el signo igual.
      final charla = Conversacion()
        ..agregar(const Mensaje.mia('#manteca#', paraLaIa: false))
        ..agregar(const Mensaje.delDiccionario('#manteca# = #burro#'))
        ..agregar(const Mensaje.mia('ciao!'));

      final turnos = charla.contenidos();

      // Instrucciones, saludo y "ciao!": el ida y vuelta del medio no está.
      expect(turnos.length, 3);
      expect(_texto(turnos.last), 'ciao!');
    });

    test('una palabra marcada en medio de la charla va sin almohadillas', () {
      final charla = Conversacion()..agregar(const Mensaje.mia('voglio #pan#'));

      expect(_texto(charla.contenidos().last), 'voglio pan');
    });
  });

  group('las instrucciones', () {
    test('ya no dicen nada de las traducciones', () {
      // Eran tres de las nueve reglas y la IA igual se equivocaba. Ahora las
      // contesta el diccionario de la app, y el prompt quedó en seis reglas
      // sobre una sola cosa: charlar y corregir.
      expect(promptDeChat, isNot(contains('#')));
      expect(promptDeChat, isNot(contains('traducción')));
      expect(promptDeChat, isNot(contains('almohadilla')));
    });

    test('piden italiano simple y respuestas cortas', () {
      expect(promptDeChat, contains('italiano simple'));
      expect(promptDeChat, contains('Correzione:'));
    });

    test('ponen la corrección como la excepción, no como la regla', () {
      expect(promptDeChat, contains('Lo normal es NO corregir'));
      expect(promptDeChat, contains('Nunca escribas un renglón de corrección'));
      // Decir "io vado" en vez de "vado" no es un error, y era lo que corregía.
      expect(promptDeChat, contains('Poner el sujeto'));
    });

    test('no piden markdown, que se leería en voz alta', () {
      expect(promptDeChat, contains('No uses markdown'));
    });
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
