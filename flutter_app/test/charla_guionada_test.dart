import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/datos/repositorio_charlas.dart';
import 'package:tukyliano/logica/charla_guionada.dart';
import 'package:tukyliano/modelos/charla.dart';

const _paso = Paso(
  id: 'saludo',
  dice: 'Buongiorno! Cosa prende?',
  espanol: '¡Buen día! ¿Qué va a tomar?',
  respuestas: [
    Respuesta(
      texto: 'Un caffè, per favore',
      espanol: 'Un café, por favor',
      claves: ['caffe'],
      sigue: 'cafe',
    ),
    Respuesta(
      texto: 'Una birra, per favore',
      espanol: 'Una cerveza, por favor',
      claves: ['birra'],
      sigue: 'birra',
    ),
  ],
);

void main() {
  group('qué contestó', () {
    test('la frase justa está bien dicha', () {
      final contestacion = queContesto(_paso, 'Un caffè, per favore');

      expect(contestacion.como, ComoContesto.bien);
      expect(contestacion.respuesta!.sigue, 'cafe');
      expect(contestacion.comoSeDice, isNull);
    });

    test('los acentos y los signos no cambian nada', () {
      // Escribir "caffe" sin acento y sin coma sigue siendo decirlo bien: lo
      // que se practica acá es escribir la frase, no el teclado.
      expect(
        queContesto(_paso, 'un caffe per favore').como,
        ComoContesto.bien,
      );
    });

    test('se entiende qué quiso decir aunque lo diga mal', () {
      final contestacion = queContesto(_paso, 'io volere un caffè');

      expect(contestacion.como, ComoContesto.casi);
      expect(contestacion.comoSeDice, 'Un caffè, per favore');
      // La charla sigue igual: entendió, y el error ya quedó mostrado.
      expect(contestacion.respuesta!.sigue, 'cafe');
    });

    test('una palabra sola alcanza para entender, pero no está bien dicha', () {
      final contestacion = queContesto(_paso, 'caffè');

      expect(contestacion.como, ComoContesto.casi);
      expect(contestacion.comoSeDice, 'Un caffè, per favore');
    });

    test('cada clave lleva a su rama', () {
      expect(queContesto(_paso, 'Una birra, per favore').respuesta!.sigue,
          'birra');
    });

    test('lo que no se parece a nada no se entiende', () {
      final contestacion = queContesto(_paso, 'dove è la stazione?');

      expect(contestacion.como, ComoContesto.noSeEntiende);
      expect(contestacion.respuesta, isNull);
      expect(contestacion.comoSeDice, isNull);
    });

    test('vacío no se entiende', () {
      expect(queContesto(_paso, '   ').como, ComoContesto.noSeEntiende);
    });

    test('gana la respuesta con más claves', () {
      // "un altro caffè" tiene el "caffe" de la primera, así que las dos dan;
      // tiene que ganar la que pide las dos palabras.
      const paso = Paso(
        id: 'nonna',
        dice: 'Vuole altro?',
        espanol: '¿Quiere algo más?',
        respuestas: [
          Respuesta(
            texto: 'Un caffè, per favore',
            espanol: '',
            claves: ['caffe'],
            sigue: 'uno',
          ),
          Respuesta(
            texto: 'Sì, un altro caffè',
            espanol: '',
            claves: ['altro', 'caffe'],
            sigue: 'otro',
          ),
        ],
      );

      expect(queContesto(paso, 'Sì, un altro caffè').respuesta!.sigue, 'otro');
      expect(queContesto(paso, 'Sì, un altro caffè').como, ComoContesto.bien);
    });

    test('el último paso no tiene nada que contestar', () {
      const fin = Paso(id: 'fin', dice: 'Arrivederci!', espanol: '', respuestas: []);

      expect(fin.esElFinal, isTrue);
      expect(queContesto(fin, 'ciao').como, ComoContesto.noSeEntiende);
    });
  });

  group('el guion del bar', () {
    late Charla bar;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final charlas = await RepositorioCharlas().cargar();
      bar = charlas.firstWhere((c) => c.id == 'bar');
    });

    test('se puede cargar y arranca donde dice', () {
      expect(bar.titulo, 'Al bar');
      expect(bar.paso(bar.primero), isNotNull);
    });

    test('ningún camino termina en un paso que no existe', () {
      // Un "sigue" mal escrito deja la charla colgada sin que nadie se entere
      // hasta que alguien la juega hasta ahí.
      for (final paso in bar.pasos) {
        for (final respuesta in paso.respuestas) {
          expect(
            bar.paso(respuesta.sigue),
            isNotNull,
            reason: '${paso.id} → ${respuesta.sigue} no existe',
          );
        }
      }
    });

    test('todos los pasos se pueden alcanzar desde el principio', () {
      final vistos = <String>{bar.primero};
      final porVer = <String>[bar.primero];
      while (porVer.isNotEmpty) {
        final paso = bar.paso(porVer.removeLast())!;
        for (final respuesta in paso.respuestas) {
          if (vistos.add(respuesta.sigue)) porVer.add(respuesta.sigue);
        }
      }

      expect(
        bar.pasos.map((p) => p.id).toSet().difference(vistos),
        isEmpty,
        reason: 'hay pasos que no se alcanzan desde ningún lado',
      );
    });

    test('toda rama termina en el final', () {
      final finales = [for (final paso in bar.pasos) if (paso.esElFinal) paso.id];

      expect(finales, isNotEmpty);
      // Y que no haya un paso sin salida que no sea un final de verdad.
      for (final paso in bar.pasos) {
        if (!paso.esElFinal) {
          expect(paso.respuestas, isNotEmpty, reason: paso.id);
        }
      }
    });

    test('cada respuesta dice bien lo que sus claves prometen', () {
      // La clave tiene que estar adentro de la frase correcta. Si no, decir la
      // frase bien no alcanzaría para avanzar, que es absurdo.
      for (final paso in bar.pasos) {
        for (final respuesta in paso.respuestas) {
          expect(
            queContesto(paso, respuesta.texto).como,
            ComoContesto.bien,
            reason: '"${respuesta.texto}" en ${paso.id}',
          );
        }
      }
    });

    test('todo tiene su traducción', () {
      for (final paso in bar.pasos) {
        expect(paso.espanol, isNotEmpty, reason: paso.id);
        for (final respuesta in paso.respuestas) {
          expect(respuesta.espanol, isNotEmpty, reason: respuesta.texto);
        }
      }
    });

    test('se puede jugar de punta a punta contestando bien', () {
      var paso = bar.paso(bar.primero)!;
      final recorrido = <String>[paso.id];

      while (!paso.esElFinal) {
        final contestacion = queContesto(paso, paso.respuestas.first.texto);
        expect(contestacion.como, ComoContesto.bien, reason: paso.id);
        paso = bar.paso(contestacion.respuesta!.sigue)!;
        recorrido.add(paso.id);
        expect(recorrido.length, lessThan(30), reason: 'da vueltas: $recorrido');
      }

      expect(recorrido.first, bar.primero);
      expect(paso.esElFinal, isTrue);
    });
  });
}
