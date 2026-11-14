import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/datos/repositorio_diccionario.dart';
import 'package:tukyliano/logica/diccionario_buscar.dart';
import 'package:tukyliano/modelos/diccionario.dart';

const _chico = Diccionario(
  italiano: {
    'finestra': ['ventana'],
    'burro': ['manteca'],
    'bambino': ['nene', 'chico'],
    'nuovo': ['nuevo'],
    'acqua': ['agua'],
    'chiave': ['llave'],
    'amico': ['amigo'],
    'ieri sera': ['anoche'],
    'come': ['cómo'],
    'stai': ['estás'],
  },
  espanol: {
    'manteca': ['burro'],
    'ventana': ['finestra'],
    'llave': ['chiave'],
    'auto': ['macchina'],
  },
);

void main() {
  group('buscar una palabra', () {
    test('del italiano al español', () {
      final hallada = traducir(_chico, 'finestra');

      expect(hallada!.comoSeDice, 'ventana');
      expect(hallada.desdeItaliano, isTrue);
      expect(hallada.completa, isTrue);
    });

    test('del español al italiano', () {
      final hallada = traducir(_chico, 'manteca');

      expect(hallada!.comoSeDice, 'burro');
      expect(hallada.desdeItaliano, isFalse);
    });

    test('las mayúsculas y las tildes no importan', () {
      expect(traducir(_chico, 'FINESTRA')!.comoSeDice, 'ventana');
      expect(traducir(_chico, '  Acquà ')!.comoSeDice, 'agua');
    });

    test('con varias acepciones las muestra todas', () {
      expect(traducir(_chico, 'bambino')!.comoSeDice, 'nene, chico');
    });

    test('la que está en los dos idiomas se lee como italiana', () {
      // "burro" existe en los dos y quiere decir cosas distintas. Gana el
      // italiano porque quien marca una palabra está leyendo italiano.
      expect(traducir(_chico, 'burro')!.comoSeDice, 'manteca');
    });

    test('la que no está no inventa nada', () {
      expect(traducir(_chico, 'sciopero'), isNull);
      expect(traducir(_chico, '   '), isNull);
    });
  });

  group('las formas que un diccionario no lista', () {
    test('el plural italiano se busca por su singular', () {
      // Un diccionario trae "bambino", no "bambini".
      expect(traducir(_chico, 'bambini')!.comoSeDice, 'nene, chico');
      expect(traducir(_chico, 'chiavi')!.comoSeDice, 'llave');
      expect(traducir(_chico, 'amici')!.comoSeDice, 'amigo');
    });

    test('el femenino también', () {
      expect(traducir(_chico, 'nuova')!.comoSeDice, 'nuevo');
      expect(traducir(_chico, 'nuove')!.comoSeDice, 'nuevo');
    });

    test('la elisión se parte', () {
      // En italiano "dell'acqua" es una sola palabra escrita, y la entrada
      // del diccionario es "acqua".
      expect(traducir(_chico, "dell'acqua")!.comoSeDice, 'agua');
      expect(traducir(_chico, "l'amico")!.comoSeDice, 'amigo');
    });

    test('el plural español se busca sin la s', () {
      expect(traducir(_chico, 'llaves')!.comoSeDice, 'chiave');
    });

    test('inventar una forma que no existe no trae nada', () {
      // Las formas son intentos: si ninguna está, no se devuelve cualquier
      // cosa.
      expect(traducir(_chico, 'xyzzi'), isNull);
    });
  });

  group('las frases', () {
    test('la frase que está entera se devuelve entera', () {
      final hallada = traducir(_chico, 'ieri sera');

      expect(hallada!.comoSeDice, 'anoche');
      expect(hallada.completa, isTrue);
    });

    test('la que no está se arma palabra por palabra', () {
      final hallada = traducir(_chico, 'come stai');

      expect(hallada!.comoSeDice, 'cómo estás');
      expect(hallada.completa, isTrue);
    });

    test('las palabras que faltan quedan como vinieron, a la vista', () {
      final hallada = traducir(_chico, 'come stai oggi');

      expect(hallada!.comoSeDice, 'cómo estás oggi');
      expect(hallada.completa, isFalse);
    });

    test('si no se entiende ni una palabra, no hay traducción', () {
      expect(traducir(_chico, 'zzz qqq'), isNull);
    });
  });

  group('el diccionario de verdad', () {
    late Diccionario diccionario;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      diccionario = await RepositorioDiccionario().cargar();
    });

    test('se carga y trae lo que dice traer', () {
      expect(diccionario.vacio, isFalse);
      expect(diccionario.italiano.length, greaterThan(13000));
      expect(diccionario.espanol.length, greaterThan(13000));
    });

    test('dice de dónde salió, que la licencia lo pide', () {
      expect(diccionario.credito, contains('FreeDict'));
      expect(diccionario.licencia, contains('CC BY-SA'));
      expect(diccionario.fuente, isNotEmpty);
    });

    test('las palabras de todos los días están', () {
      for (final palabra in [
        'finestra', 'caffè', 'conto', 'panino', 'domani', 'soldi',
        'lavoro', 'macchina', 'tavolo', 'bicchiere', 'parlare', 'mangiare',
      ]) {
        expect(traducir(diccionario, palabra), isNotNull, reason: palabra);
      }
    });

    test('las formas conjugadas también, que es lo que falta en FreeDict', () {
      for (final forma in ['sono', 'ho', 'voglio', 'andato', 'fatto']) {
        expect(traducir(diccionario, forma), isNotNull, reason: forma);
      }
    });

    test('el español es rioplatense y no neutro', () {
      expect(traducir(diccionario, 'auto')!.comoSeDice, contains('macchina'));
      expect(traducir(diccionario, 'pileta')!.comoSeDice, contains('piscina'));
      expect(traducir(diccionario, 'tarjeta'), isNotNull);
      expect(traducir(diccionario, 'medialuna')!.comoSeDice,
          contains('cornetto'));
      // FreeDict dice que "macchina" es "máquina", que es cierto y no es lo
      // que uno quiere leer cuando está hablando de un auto.
      expect(traducir(diccionario, 'macchina')!.comoSeDice, startsWith('auto'));
    });

    test('las claves están normalizadas, sin tildes ni mayúsculas', () {
      for (final clave in diccionario.italiano.keys.take(500)) {
        expect(clave, clave.toLowerCase(), reason: clave);
        expect(clave, isNot(matches(RegExp('[áéíóúàèìòù]'))), reason: clave);
      }
    });
  });
}
