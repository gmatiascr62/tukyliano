import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/ia/gemini.dart';
import 'package:tukyliano/ia/prompts.dart';

void main() {
  group('promptGenerarFrase', () {
    String prompt({String conjugacion = 'sarò', int semilla = 1}) =>
        promptGenerarFrase(
          verbo: 'essere',
          traduccion: 'ser/estar',
          tiempo: 'futuro_semplice',
          persona: 'io',
          conjugacionItaliana: conjugacion,
          azar: Random(semilla),
        );

    test('incluye verbo, traducción, tiempo y persona', () {
      final p = prompt();
      expect(p, contains("verbo 'essere' (ser/estar)"));
      expect(p, contains('conjugado en futuro semplice'));
      expect(p, contains("persona 'io'"));
    });

    test('exige la conjugación exacta cuando se la pasan', () {
      expect(
        prompt(),
        contains("el verbo tiene que aparecer conjugado exactamente como 'sarò'"),
      );
    });

    test('omite esa exigencia si no hay conjugación cargada', () {
      final p = prompt(conjugacion: '');
      expect(p, isNot(contains('conjugado exactamente como')));
      // El resto del prompt sigue completo.
      expect(p, contains("persona 'io'"));
      expect(p, contains('Respondé SOLO un JSON válido'));
    });

    test('pide que ambas frases usen la misma persona', () {
      expect(
        prompt(),
        contains('tienen que ser la misma frase, con la misma persona'),
      );
    });

    test('pide español de Latinoamérica', () {
      expect(prompt(), contains("'ustedes', nunca 'vosotros'"));
    });

    test('sortea un tema de la lista', () {
      final p = prompt();
      final usados = temasFrase.where((t) => p.contains('tiene que ser: $t.'));
      expect(usados.length, 1);
    });

    test('sortea dos ejemplos distintos de la lista', () {
      final p = prompt();
      final usados = ejemplosFrase.where((e) => p.contains("'$e'")).toList();
      expect(usados.length, 2);
    });

    test('el tema cambia entre llamadas', () {
      final temas = <String>{};
      for (var i = 0; i < 30; i++) {
        final p = prompt(semilla: i);
        temas.add(temasFrase.firstWhere((t) => p.contains('tiene que ser: $t.')));
      }
      // Con 20 temas y 30 sorteos tiene que salir más de uno.
      expect(temas.length, greaterThan(1));
    });
  });

  group('promptVerificarFrase', () {
    test('incluye la frase, la referencia y la respuesta', () {
      final p = promptVerificarFrase(
        fraseEs: 'Mañana estaré en la escuela',
        italianoReferencia: 'Domani sarò a scuola',
        respuestaUsuario: 'domani sarò alla scuola',
      );

      expect(p, contains('Frase en español: "Mañana estaré en la escuela"'));
      expect(p, contains('referencia al italiano: "Domani sarò a scuola"'));
      expect(p, contains('Respuesta del alumno: "domani sarò alla scuola"'));
      expect(p, contains('CORRECTO o INCORRECTO'));
    });
  });

  group('extraerJson', () {
    test('lee un JSON pelado', () {
      final datos = extraerJson('{"espanol": "Hoy comemos pizza", "italiano": "Oggi mangiamo la pizza"}');
      expect(datos['espanol'], 'Hoy comemos pizza');
    });

    test('lee un JSON envuelto en markdown', () {
      final datos = extraerJson('''
```json
{"espanol": "Hace frío", "italiano": "Fa freddo"}
```
''');
      expect(datos['italiano'], 'Fa freddo');
    });

    test('lee un JSON con texto alrededor', () {
      final datos = extraerJson(
          'Acá va: {"espanol": "Voy", "italiano": "Vado"} listo.');
      expect(datos['espanol'], 'Voy');
    });

    test('falla si no hay JSON', () {
      expect(() => extraerJson('no hay nada acá'), throwsFormatException);
    });
  });

  group('promptGenerarFrase con gerundio', () {
    String prompt() => promptGenerarFrase(
          verbo: 'volere',
          traduccion: 'querer',
          tiempo: 'gerundio',
          persona: '-',
          conjugacionItaliana: 'volendo',
          azar: Random(3),
        );

    test('pide el gerundio y no una persona', () {
      final p = prompt();
      expect(p, contains('usando el gerundio del verbo'));
      expect(p, isNot(contains("persona '-'")));
      expect(p, isNot(contains('conjugado en gerundio')));
    });

    test('exige la forma exacta del gerundio', () {
      expect(
        prompt(),
        contains("el gerundio tiene que aparecer exactamente como 'volendo'"),
      );
    });

    test('igual pide que las dos frases coincidan', () {
      expect(prompt(), contains('tienen que ser la misma frase'));
    });
  });
}
