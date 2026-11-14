import '../modelos/charla.dart';
import 'pronunciacion.dart';

/// Qué pasó con lo que se escribió en una charla guionada.
enum ComoContesto {
  /// Dijo una de las respuestas posibles, y la dijo bien.
  bien,

  /// Se entendió qué quiso decir, pero no lo dijo como se dice.
  casi,

  /// No se parece a nada de lo que se puede contestar acá.
  noSeEntiende,
}

/// Lo que la pantalla necesita saber después de que alguien escribió algo.
class Contestacion {
  const Contestacion({
    required this.como,
    this.respuesta,
  });

  final ComoContesto como;

  /// Cuál de las respuestas del paso se entendió. Null si no se entendió
  /// ninguna.
  final Respuesta? respuesta;

  /// La frase bien dicha, para mostrar cuando salió [ComoContesto.casi].
  ///
  /// Nunca puede estar mal: sale del guion, no de un modelo que la improvisa.
  String? get comoSeDice => como == ComoContesto.casi ? respuesta?.texto : null;
}

/// Decide qué hacer con lo que se escribió en un paso.
///
/// Son dos preguntas distintas y se contestan por separado:
///
/// 1. **¿Qué quiso decir?** Se busca la respuesta cuyas palabras clave estén
///    todas en lo que escribió. Con que diga "caffè" alcanza para saber que
///    pidió un café, escriba como escriba el resto.
/// 2. **¿Lo dijo bien?** Recién ahí se compara lo escrito, palabra por
///    palabra, contra la frase del guion. Si coincide, está bien; si no, se
///    entendió pero hay que mostrarle cómo se dice.
///
/// Separarlas es lo que hace que la corrección sirva: "io volere un caffè" se
/// entiende perfecto y está mal dicho, y las dos cosas son ciertas a la vez.
Contestacion queContesto(Paso paso, String escrito) {
  final dichas = enPalabras(escrito);
  if (dichas.isEmpty) {
    return const Contestacion(como: ComoContesto.noSeEntiende);
  }

  final entendida = _cualQuisoDecir(paso, dichas);
  if (entendida == null) {
    return const Contestacion(como: ComoContesto.noSeEntiende);
  }

  final comoSeDice = enPalabras(entendida.texto);
  final loDijoBien = dichas.length == comoSeDice.length &&
      List.generate(dichas.length, (i) => dichas[i] == comoSeDice[i])
          .every((igual) => igual);

  return Contestacion(
    como: loDijoBien ? ComoContesto.bien : ComoContesto.casi,
    respuesta: entendida,
  );
}

/// La respuesta cuyas claves estén todas en lo escrito.
///
/// Si hay más de una, gana la que tenga más claves: en un paso donde se puede
/// pedir "un caffè" o "un altro caffè", escribir "un altro caffè" tiene que
/// caer en la segunda y no en la primera, que también daría.
Respuesta? _cualQuisoDecir(Paso paso, List<String> dichas) {
  final pedazos = _conLasElisiones(dichas);
  Respuesta? mejor;
  var cuantasClaves = 0;

  for (final respuesta in paso.respuestas) {
    if (respuesta.claves.isEmpty) continue;
    final estanTodas = respuesta.claves.every(
      (clave) => pedazos.contains(normalizar(clave)),
    );
    if (estanTodas && respuesta.claves.length > cuantasClaves) {
      mejor = respuesta;
      cuantasClaves = respuesta.claves.length;
    }
  }

  return mejor;
}

/// Las palabras, más los pedazos de las que llevan apóstrofo.
///
/// En italiano la elisión pega dos palabras en una: "dall'Argentina",
/// "l'acqua", "un'ora". Para buscar una clave eso es un estorbo, porque la
/// clave "argentina" no está adentro de la palabra "dall'argentina".
///
/// El apóstrofo se parte acá y no en [normalizar] a propósito: ahí se usa para
/// ver si la frase está bien escrita, y escribir "lacqua" en vez de "l'acqua"
/// es justamente uno de los errores que hay que mostrar. Son dos preguntas
/// distintas: qué quiso decir —donde conviene ser generoso— y si lo dijo bien
/// —donde no—.
Set<String> _conLasElisiones(List<String> palabras) => {
      for (final palabra in palabras) ...[
        palabra,
        if (palabra.contains("'"))
          for (final pedazo in palabra.split("'"))
            if (pedazo.isNotEmpty) pedazo,
      ],
    };
