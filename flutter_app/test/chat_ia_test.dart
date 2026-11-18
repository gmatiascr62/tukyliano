import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/ia/chat.dart';

/// El texto de un turno del pedido a la API.
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
    test('el saludo va aparte y después la charla, en orden', () {
      // El servidor recibe el saludo por su cuenta, así que acá van solo los
      // que vinieron después.
      final charla = Conversacion()
        ..agregar(const Mensaje.mia('mi chiamo Matías'))
        ..agregar(const Mensaje.deLaIa('Piacere! Dove abiti?'))
        ..agregar(const Mensaje.mia('abito a Buenos Aires'));

      expect(charla.paraElServidor(), [
        {'quien': 'yo', 'texto': 'mi chiamo Matías'},
        {'quien': 'ia', 'texto': 'Piacere! Dove abiti?'},
        {'quien': 'yo', 'texto': 'abito a Buenos Aires'},
      ]);
    });

    test('los avisos de la app no viajan', () {
      // Un cartel de "no hay internet" no es parte de la charla: si viajara,
      // la IA lo leería como si el alumno lo hubiera escrito.
      final charla = Conversacion()
        ..agregar(const Mensaje.mia('ciao'))
        ..agregar(const Mensaje.aviso('No se pudo hablar con la IA.'));

      expect(charla.paraElServidor(), [
        {'quien': 'yo', 'texto': 'ciao'},
      ]);
    });

    test('ir al diccionario no entra en lo que la IA recuerda', () {
      // Buscar una palabra no es charlar. Si entrara en el historial, la IA
      // creería que se habló de eso, o copiaría el formato con el signo igual.
      final charla = Conversacion()
        ..agregar(const Mensaje.mia('#manteca#', paraLaIa: false))
        ..agregar(const Mensaje.delDiccionario('#manteca# = #burro#'))
        ..agregar(const Mensaje.mia('ciao!'));

      expect(charla.paraElServidor(), [
        {'quien': 'yo', 'texto': 'ciao!'},
      ]);
    });

    test('una palabra marcada va sin almohadillas', () {
      final charla = Conversacion()..agregar(const Mensaje.mia('voglio #pan#'));

      expect(charla.paraElServidor().last['texto'], 'voglio pan');
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

  group('el final de la escena', () {
    test('la marca en un renglón aparte cierra', () {
      expect(cierraLaEscena('Arrivederci!\nFINE'), isTrue);
    });

    test('la marca pegada al final de la frase también', () {
      // El modelo devolvió "Ecco il resto. Arrivederci. FINE".
      expect(cierraLaEscena('Ecco il resto. Arrivederci. FINE'), isTrue);
    });

    test('la marca sola cierra', () {
      expect(cierraLaEscena('FINE'), isTrue);
    });

    test('"fine" en minúscula no cierra nada', () {
      // Es una palabra italiana común: el final de algo. Por eso la marca va
      // en mayúsculas.
      expect(cierraLaEscena('È la fine della storia'), isFalse);
      expect(cierraLaEscena('Alla fine'), isFalse);
    });

    test('la marca en el medio no cierra', () {
      expect(cierraLaEscena('FINE. Ma dimmi, come stai?'), isFalse);
    });

    test('sacarla deja el mensaje como se dijo', () {
      expect(
        sinLaMarcaDelFinal('Ecco il resto. Arrivederci!\nFINE'),
        'Ecco il resto. Arrivederci!',
      );
      expect(
        sinLaMarcaDelFinal('Arrivederci. FINE'),
        'Arrivederci.',
      );
    });

    test('sacarla de un mensaje sin marca no cambia nada', () {
      expect(sinLaMarcaDelFinal('Ecco a te.'), 'Ecco a te.');
    });
  });

  group('la marca de la corrección', () {
    test('se reconoce la que pide el servidor', () {
      expect(sinCorreccionRepetida('Volevi dire: ciao\nCiao!', 'ciao'),
          'Ciao!');
    });

    test('se reconoce la vieja, para los celulares sin actualizar', () {
      expect(sinCorreccionRepetida('Correzione: ciao\nCiao!', 'ciao'),
          'Ciao!');
    });

    test('se reconoce la mitad en castellano que a veces devuelve el modelo',
        () {
      // "Volevi decir:" no es italiano ni castellano: es el contagio de que
      // las instrucciones del servidor están escritas en castellano. Pasó
      // dos veces en una sola escena del bar.
      expect(sinCorreccionRepetida('Volevi decir: ciao\nCiao!', 'ciao'),
          'Ciao!');
    });
  });

  group('la marca de corrección en pantalla', () {
    test('se lee en castellano y la frase corregida queda intacta', () {
      // El aviso y el barista llegan en la misma burbuja. Con los dos en
      // italiano, el aviso se lee como una frase más de la charla.
      expect(
        conLaMarcaEnCastellano('Volevi dire: Io bevo il caffè\nEcco a te.'),
        'Se dice así: Io bevo il caffè\nEcco a te.',
      );
    });

    test('también la vieja y la mitad en castellano', () {
      expect(conLaMarcaEnCastellano('Correzione: Io bevo'),
          'Se dice así: Io bevo');
      expect(conLaMarcaEnCastellano('Volevi decir: Io bevo'),
          'Se dice así: Io bevo');
    });

    test('no toca un mensaje sin corrección', () {
      for (final dicho in [
        'Ecco a te.',
        'Sì, ecco. Vuoi altro?',
        // Ojo con esta: dice "dire" pero no es la marca.
        'Cosa vuoi dire?',
      ]) {
        expect(conLaMarcaEnCastellano(dicho), dicho, reason: dicho);
      }
    });

    test('para leer en voz alta se saca la marca entera', () {
      // La voz es italiana: leer "Se dice así" con acento italiano suena a
      // error, y leer "Volevi dire" sería decirle en italiano algo que no
      // es parte de la charla.
      expect(
        paraLeerEnVozAlta('Volevi dire: Io bevo il caffè\nEcco a te.'),
        'Io bevo il caffè\nEcco a te.',
      );
      expect(paraLeerEnVozAlta('Ecco a te.'), 'Ecco a te.');
    });

    test('también la castellana, que es la que llega', () {
      // Para cuando esto corre la marca ya se cambió a castellano, así que
      // mirar solo la italiana no servía de nada: la voz terminaba diciendo
      // "Se dice así" con acento italiano en todas las correcciones, que es
      // justo lo que esto vino a evitar.
      expect(
        paraLeerEnVozAlta('Se dice así: Io bevo il caffè\nEcco a te.'),
        'Io bevo il caffè\nEcco a te.',
      );
    });
  });

  group('lo que dijiste, arriba de la corrección', () {
    // Es la mitad de una comparación: arriba lo que escribió traducido
    // literal al castellano, abajo cómo se dice en italiano. Matías lo pidió
    // así de preciso: "que la parte que dice vos dijiste esté en español y
    // se dice así en italiano".
    const delModelo = 'Hai scritto: yo querer un café\n'
        'Volevi dire: Vorrei un caffè\n'
        'Ecco a te.';

    test('la marca se lee en castellano y la traducción queda intacta', () {
      expect(
        conLaMarcaEnCastellano(delModelo),
        'Vos dijiste: yo querer un café\n'
            'Se dice así: Vorrei un caffè\n'
            'Ecco a te.',
      );
    });

    test('también si el modelo dice "hai detto"', () {
      // Alterna entre los dos verbos aunque el prompt pida uno solo.
      expect(conLaMarcaEnCastellano('Hai detto: yo querer un café'),
          'Vos dijiste: yo querer un café');
    });

    test('un "hai scritto" en medio de una frase no es la marca', () {
      // La marca es el principio del renglón. En medio de una frase el
      // barista está hablando italiano y hay que dejarlo en paz.
      const charlando = 'Cosa hai scritto: non si capisce.';
      expect(conLaMarcaEnCastellano(charlando), charlando);
    });

    test('la frase equivocada no se lee en voz alta', () {
      // Esta es la que importa, y ahora por dos motivos: el renglón está en
      // castellano —la voz es italiana y lo leería con acento— y además es
      // el error. Leérselo al oído es lo contrario de para qué está.
      final paraLaVoz = paraLeerEnVozAlta(conLaMarcaEnCastellano(delModelo));

      expect(paraLaVoz, isNot(contains('querer')));
      expect(paraLaVoz, isNot(contains('Vos dijiste')));
      expect(paraLaVoz, 'Vorrei un caffè\nEcco a te.');
    });

    test('tampoco se lee si llega con la marca todavía en italiano', () {
      // Por si alguna vez se muestra sin pasar por la traducción de marcas.
      expect(paraLeerEnVozAlta(delModelo), 'Vorrei un caffè\nEcco a te.');
    });

    test('sin corrección al lado, el renglón se va', () {
      // Si la corrección repetía la frase tal cual, se filtra. El de arriba
      // quedaría solo, diciéndole en castellano lo que acaba de escribir,
      // sin nada con qué compararlo.
      expect(
        sinCorreccionRepetida(
          'Hai scritto: yo bebo el café\n'
              'Volevi dire: io bevo il caffè\n'
              'Ecco a te.',
          'io bevo il caffè',
        ),
        'Ecco a te.',
      );
    });

    test('si el modelo se olvida de la corrección, tampoco queda solo', () {
      expect(
        sinCorreccionRepetida('Hai scritto: yo querer un café\nEcco a te.',
            'io volere un caffè'),
        'Ecco a te.',
      );
    });

    test('con la corrección al lado se queda', () {
      // El caso de siempre: la corrección dice algo distinto de lo que
      // escribió, así que la comparación tiene sentido y van los dos.
      expect(sinCorreccionRepetida(delModelo, 'io volere un caffè'),
          delModelo);
    });
  });
}
