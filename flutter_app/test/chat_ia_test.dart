import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/ia/chat.dart';

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

    test('de la respuesta se queda solo el renglón de la traducción', () {
      // Le pedimos que no charle, pero a veces igual charla: acá se recorta.
      const contestado = '#manteca# = #burro#\n\n'
          'Capisco, ti piace cucinare. Cosa prepari?';

      expect(soloLasTraducciones(contestado), '#manteca# = #burro#');
    });

    test('se quedan todos los renglones si hubo varios pedidos', () {
      const contestado = '#manteca# = #burro#\n#pan# = #pane#\nChe cucini?';

      expect(
        soloLasTraducciones(contestado),
        '#manteca# = #burro#\n#pan# = #pane#',
      );
    });

    test('si no vino ningún renglón con el formato se muestra todo', () {
      // Antes mostrar algo raro que dejar la burbuja vacía.
      const contestado = 'Non ho capito, puoi ripetere?';

      expect(soloLasTraducciones(contestado), contestado);
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

    test('el prompt de la charla lleva el saludo y lo dicho', () {
      final charla = Conversacion()..agregar(const Mensaje.mia('ciao'));

      final prompt = charla.prompt();

      expect(prompt, contains(promptDeChat));
      expect(prompt, contains(charla.saludo));
      expect(prompt, contains('<|im_start|>user\nciao'));
    });

    test('la memoria son los turnos anteriores, en orden', () {
      final charla = Conversacion()
        ..agregar(const Mensaje.mia('mi chiamo Matías'))
        ..agregar(const Mensaje.deLaIa('Piacere! Dove abiti?'))
        ..agregar(const Mensaje.mia('abito a Buenos Aires'));

      final prompt = charla.prompt();

      expect(
        prompt.indexOf('mi chiamo Matías'),
        lessThan(prompt.indexOf('Piacere! Dove abiti?')),
      );
      expect(
        prompt.indexOf('Piacere! Dove abiti?'),
        lessThan(prompt.indexOf('abito a Buenos Aires')),
      );
    });

    test('los avisos de la app no se le mandan a la IA', () {
      // Un cartel de "no hay internet" no es parte de la charla: si se
      // mandara, la IA lo leería como si el alumno lo hubiera escrito.
      final charla = Conversacion()
        ..agregar(const Mensaje.mia('ciao'))
        ..agregar(const Mensaje.aviso('No se pudo hablar con la IA.'));

      expect(charla.prompt(), isNot(contains('No se pudo hablar')));
    });
  });

  group('el prompt para el modelo', () {
    test('lleva las instrucciones, el saludo y lo dicho, en ChatML', () {
      // ChatML es el formato con el que entrenaron a Qwen3: escrito de otra
      // manera, el modelo contesta cualquier cosa.
      final prompt = promptDeLaCharla(
        saludo: 'Ciao! Che musica ascolti?',
        mensajes: [
          const Mensaje.deLaIa('Ciao! Che musica ascolti?'),
          const Mensaje.mia('Mi piace il rock'),
        ],
      );

      expect(prompt, contains('<|im_start|>system'));
      expect(prompt, contains(promptDeChat));
      expect(prompt, contains('<|im_start|>assistant\nCiao! Che musica ascolti?'));
      expect(prompt, contains('<|im_start|>user\nMi piace il rock'));
      // Termina abriendo el turno del profesor: "ahora escribís vos".
      expect(prompt, endsWith('<|im_start|>assistant\n'));
    });

    test('se acuerda solo de los últimos mensajes', () {
      // Cada mensaje de más son tokens que el celular tiene que volver a
      // procesar en cada respuesta, y el contexto es de 1024.
      final mensajes = [
        const Mensaje.deLaIa('Ciao!'),
        for (var i = 0; i < 20; i++) Mensaje.mia('mensaje $i'),
      ];

      final prompt = promptDeLaCharla(
        saludo: 'Ciao!',
        mensajes: mensajes,
        cuantosRecordar: 4,
      );

      expect(prompt, contains('mensaje 19'));
      expect(prompt, contains('mensaje 16'));
      expect(prompt, isNot(contains('mensaje 15')));
      // El saludo va siempre: es lo que le recuerda de qué tema hablaban.
      expect(prompt, contains('Ciao!'));
    });

    test('los avisos de la app no se le mandan', () {
      final prompt = promptDeLaCharla(
        saludo: 'Ciao!',
        mensajes: [
          const Mensaje.deLaIa('Ciao!'),
          const Mensaje.aviso('Se cortó internet'),
        ],
      );

      expect(prompt, isNot(contains('Se cortó internet')));
    });

    test('las instrucciones son cortas, que es lo que un modelo chico sigue',
        () {
      expect(promptDeChat.split('\n').length, lessThan(15));
      expect(promptDeChat, contains('profesor de italiano'));
      expect(promptDeChat, contains('Correzione:'));
      // El /no_think era para apagarle el razonamiento a Qwen3. El modelo de
      // ahora contesta de una, y pedirle algo que no entiende es una regla
      // más que puede mezclar con las otras.
      expect(promptDeChat, isNot(contains('/no_think')));
    });

    test('las instrucciones no dejan un molde para copiar', () {
      // Decía "empezá con este renglón exacto: Correzione: la frase bien
      // escrita", y el modelo lo copió tal cual a la pantalla.
      expect(promptDeChat, isNot(contains('la frase bien escrita')));
    });
  });

  group('cuando copia el molde en vez de corregir', () {
    test('se saca el renglón y queda el resto', () {
      // Lo que contestó de verdad a "Voglio imparare i verbi".
      const respuesta = 'Verbo è il verbo italiano che indica azioni.\n'
          'Correzione: la frase bien escrita "Avendo", "Fare", "Essere".';

      expect(
        sinCorreccionDelMolde(respuesta),
        'Verbo è il verbo italiano che indica azioni.',
      );
    });

    test('una corrección de verdad no se toca', () {
      const respuesta = 'Correzione: Ho mangiato la pizza.\nBene! E tu?';

      expect(sinCorreccionDelMolde(respuesta), respuesta);
    });

    test('si no queda nada, no se inventa nada', () {
      expect(sinCorreccionDelMolde('Correzione: la frase corregida'), isEmpty);
    });

    test('una frase en italiano que no es corrección se deja', () {
      const respuesta = 'La frase corregida se dice "la frase corretta".';

      expect(sinCorreccionDelMolde(respuesta), respuesta);
    });
  });

  group('el prompt para traducir', () {
    test('es otro, sin las reglas de la charla', () {
      final prompt = promptDeLaTraduccion('manteca');

      expect(prompt, contains(promptDeTraduccion));
      expect(prompt, isNot(contains(promptDeChat)));
      expect(prompt, contains('Traducí al otro idioma: manteca'));
    });

    test('lleva ejemplos, que es lo que un modelo chico copia', () {
      final prompt = promptDeLaTraduccion('manteca');

      expect(prompt, contains('<|im_start|>assistant\nburro'));
      expect(prompt, contains('<|im_start|>assistant\nventana'));
    });

    test('no le dice para qué lado traducir: se lo enseñan los ejemplos', () {
      // Adivinar el idioma con reglas fallaba la mitad de las veces:
      // "ventana" y "finestra" se escriben demasiado parecido.
      final prompt = promptDeLaTraduccion('finestra');

      expect(prompt, contains('Traducí al otro idioma: finestra'));
      expect(promptDeTraduccion, contains('Nunca devolvés la misma palabra'));
    });
  });

  group('limpiar lo que contestó', () {
    test('saca el bloque de razonamiento', () {
      expect(
        limpiarRespuesta('<think>a ver, me pregunta...</think>Ciao! Tutto bene?'),
        'Ciao! Tutto bene?',
      );
    });

    test('un razonamiento sin cerrar se corta ahí', () {
      // Se quedó pensando y lo cortamos: de ahí para adelante no hay respuesta.
      expect(
        limpiarRespuesta('Ciao!<think>ahora pienso y pienso'),
        'Ciao!',
      );
    });

    test('saca las marcas de turno que se le escapan', () {
      expect(limpiarRespuesta('Tutto bene!<|im_end|>'), 'Tutto bene!');
      expect(
        limpiarRespuesta('Tutto bene!<|im_start|>user\nhola'),
        'Tutto bene!',
      );
    });

    test('una respuesta limpia no se toca', () {
      expect(limpiarRespuesta('  Ciao! Come va?  '), 'Ciao! Come va?');
    });
  });
}
