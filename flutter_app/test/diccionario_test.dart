import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
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

  group('leer las fábulas con el diccionario', () {
    late Diccionario diccionario;
    late List<String> palabras;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      diccionario = await RepositorioDiccionario().cargar();
      final catalogo = jsonDecode(
        await rootBundle.loadString('assets/favole.json'),
      ) as Map<String, dynamic>;
      final vistas = <String>{};
      for (final favola in catalogo['favole'] as List) {
        for (final renglon in (favola as Map)['renglones'] as List) {
          final texto = (renglon as Map)['t'] as String;
          for (final palabra in texto.split(RegExp(r'[\s/]+'))) {
            final limpia = palabra
                .toLowerCase()
                .replaceAll(RegExp(r"[^\p{L}'’]", unicode: true), '');
            if (limpia.isNotEmpty) vistas.add(limpia);
          }
        }
      }
      palabras = vistas.toList()..sort();
    });

    /// Los nombres propios del libro. No van en un diccionario: Garibaldi
    /// no se traduce. Están acá para que el test pueda decir "todo lo
    /// demás tiene que estar" en vez de conformarse con un porcentaje.
    const nombres = {
      'simonide', 'polluce', 'rochefoucauld', 'orecchialunga', 'malerba',
      'lamagna', 'l’olimpo', 'cassandra', 'bertoldo', 'bertoldi',
      'all’elicona',
    };

    test('se puede tocar cualquier palabra y sale algo', () {
      // Lo que mide esto es la experiencia completa: diccionario, tabla de
      // formas, apóstrofo, apócope y las traducciones, todo junto. Empezó
      // en 82 de cada 100 palabras y está en 99.
      final sinNada = [
        for (final palabra in palabras)
          if (!nombres.contains(palabra) && traducir(diccionario, palabra) == null)
            palabra,
      ];
      expect(sinNada, isEmpty,
          reason: 'no se encuentran: ${sinNada.take(25).join(" ")}');
    });

    test('las que Matías probó a mano', () {
      // lumicino la tocó él en el primer renglón de Il Lupo e il Cane y no
      // estaba. Ningún diccionario italiano-español libre la trae.
      for (final (palabra, dice) in [
        ('lumicino', 'velita'),
        ('babbuasso', 'pavote'),
        ('stracciata', 'desgarrada'),
        ('garbo', 'gracia'),
      ]) {
        final hallada = traducir(diccionario, palabra);
        expect(hallada, isNotNull, reason: palabra);
        expect(hallada!.comoSeDice, contains(dice), reason: palabra);
      }
    });

    test('los modismos están, y la forma también', () {
      // Matías tocó "lumicino" en "Un Lupo già ridotto al lumicino" y le
      // salió "velita, luz baja". El lobo no está reducido a una velita:
      // está en las últimas.
      //
      // Lo que falló no fue el modelo sino cómo se le preguntaba: de a
      // treinta palabras por vez pierde los modismos, y de a una pierde la
      // forma gramatical. Por eso ahora se juntan las dos corridas, y este
      // test tiene las dos mitades para que no se pueda arreglar una
      // rompiendo la otra.
      expect(traducir(diccionario, 'lumicino')!.comoSeDice,
          contains('las últimas'));

      // La forma: plural donde va plural, imperfecto donde va imperfecto.
      expect(traducir(diccionario, 'pecchie')!.comoSeDice, startsWith('abejas'));
      expect(traducir(diccionario, 'dicean')!.comoSeDice, startsWith('decían'));
    });
  });

  group('la tabla de formas conjugadas', () {
    late Diccionario diccionario;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      diccionario = await RepositorioDiccionario().cargar();
    });

    test('se carga y dice de dónde salió, que la licencia lo pide', () {
      expect(diccionario.formas.length, greaterThan(50000));
      expect(diccionario.creditoDeLasFormas, contains('kaikki.org'));
    });

    test('resuelve conjugaciones que ninguna regla de plurales adivina', () {
      // Lo que mide esto no es que estén en la tabla: es que al tocarlas en
      // un texto salga algo. Son las que antes no salían.
      for (final (forma, base) in [
        ('abbia', 'avere'),
        ('avesse', 'avere'),
        ('accadde', 'accadere'),
        ('aggiunse', 'aggiungere'),
        ('fossero', 'essere'),
        ('cadde', 'cadere'),
      ]) {
        final hallada = traducir(diccionario, forma);
        expect(hallada, isNotNull, reason: forma);
        expect(hallada!.vieneDe, base, reason: forma);
      }
    });

    test('resuelve los apócopes del verso, que es para lo que se trajo', () {
      // Il Lupo e il Cane y las otras veintiuna están en italiano del siglo
      // XIX, y el verso corta las palabras para que entren en el metro.
      for (final forma in ['ancor', 'aver', 'andiam', 'allor', 'aspettar']) {
        expect(traducir(diccionario, forma), isNotNull, reason: forma);
      }
    });

    test('no se mete cuando la palabra está tal cual en el diccionario', () {
      // "parlare" es una palabra de diccionario y además la base de medio
      // centenar de formas. Cuando se toca ella misma se muestra ella, sin
      // ningún "viene de".
      for (final palabra in ['come', 'parlare', 'acqua', 'bello']) {
        expect(diccionario.italiano.containsKey(palabra), isTrue,
            reason: palabra);
        final hallada = traducir(diccionario, palabra);
        expect(hallada, isNotNull, reason: palabra);
        expect(hallada!.vieneDe, isEmpty, reason: palabra);
      }
    });

    test('no trae palabras derivadas disfrazadas de formas', () {
      // Kaikki mezcla, en el mismo campo, las formas de una palabra con las
      // palabras derivadas de ella: "cagnolino" (perrito) y "cagnaccio"
      // (perrazo) figuran como formas de "cane", y "nepalese" como forma de
      // "Nepal". Traducir "nepalese" por "Nepal" es mentir, y el que lee no
      // tiene con qué darse cuenta.
      for (final derivada in [
        'cagnolino', 'cagnaccio', 'abatino', 'nepalese', 'marittimo',
      ]) {
        expect(diccionario.formas[derivada], isNull, reason: derivada);
      }
    });

    test('ninguna forma apunta a una palabra que no se puede traducir', () {
      // Una forma cuya base no está en el diccionario es peso muerto: se
      // resuelve y después no hay nada que mostrar.
      for (final entrada in diccionario.formas.entries.take(3000)) {
        expect(diccionario.italiano.containsKey(entrada.value), isTrue,
            reason: '${entrada.key} → ${entrada.value}');
      }
    });

    test('ninguna forma es una palabra que ya está en el diccionario', () {
      for (final forma in diccionario.formas.keys.take(3000)) {
        expect(diccionario.italiano.containsKey(forma), isFalse, reason: forma);
      }
    });

    test('las formas son palabras y no pedazos de tabla', () {
      // Kaikki filtra metadatos como si fueran palabras: con el tag
      // table-tags la "forma" es literalmente "irregular", y con
      // inflection-template es "it-conj".
      for (final forma in diccionario.formas.keys) {
        expect(forma, matches(RegExp(r"^[a-z][a-z']*$")), reason: forma);
      }
      for (final basura in ['irregular', 'itconj', 'infinitive']) {
        expect(diccionario.formas[basura], isNull, reason: basura);
      }
    });

    test('el apóstrofo curvo se busca igual que el recto', () {
      // Los textos de Wikisource usan ’ y el diccionario guarda '. Sin
      // esto, "d’un" se busca como "dun" —el apóstrofo se caía al limpiar
      // la palabra— y la elisión no se partía nunca. Son 146 palabras de
      // las veintidós fábulas.
      for (final palabra in ['d’un', 'l’arte', 'ch’io', 'dell’amico']) {
        expect(traducir(diccionario, palabra), isNotNull, reason: palabra);
        // Y el mismo resultado escrito con el apóstrofo recto.
        expect(
          traducir(diccionario, palabra.replaceAll('’', "'"))!.comoSeDice,
          traducir(diccionario, palabra)!.comoSeDice,
          reason: palabra,
        );
      }
    });

    test('el apócope del verso se resuelve', () {
      // "contar" por contare, "ciel" por cielo, "facciam" por facciamo.
      for (final forma in ['contar', 'ciel', 'facciam', 'passar', 'morir']) {
        expect(traducir(diccionario, forma), isNotNull, reason: forma);
      }
    });

    test('el apócope no le gana a una palabra que existe', () {
      // "col" es "con el", no "collo" (cuello), y "colla" acá es "con la"
      // antes que "pegamento". La regla de apócope agrega una vocal a
      // cualquier cosa y acierta de casualidad, así que va última y
      // además estas están escritas a mano.
      expect(traducir(diccionario, 'col')!.comoSeDice, 'con el');
      expect(traducir(diccionario, 'colla')!.comoSeDice, startsWith('con la'));
    });

    test('las palabras de todos los días que faltaban, están', () {
      // El diccionario tenía 14.000 entradas y no tenía "grande". Salieron
      // de contar qué no encontraba la app en las veintidós fábulas.
      for (final palabra in [
        'tanto', 'grande', 'subito', 'qualche', 'mezzo', 'grosso',
        'dietro', 'contro', 'dunque', 'assai', 'maestro', 'bestia',
      ]) {
        expect(diccionario.italiano[palabra], isNotNull, reason: palabra);
      }
    });

    test('sin el archivo de formas el diccionario sigue andando', () {
      // Perder las conjugaciones es perder la mitad de las palabras de un
      // texto; perder el diccionario es perder el traductor. Son dos
      // archivos y dos try aparte justamente por esto.
      expect(
        const Diccionario(italiano: {'avere': ['tener']}).formas,
        isEmpty,
      );
      expect(traducir(const Diccionario(italiano: {'avere': ['tener']}),
          'avere'), isNotNull);
    });
  });
}
