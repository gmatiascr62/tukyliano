import 'gemini.dart';

/// El primer mensaje, el que ya está en pantalla cuando se entra al chat.
///
/// No lo escribe la IA: lo escribimos nosotros para que la charla arranque sin
/// gastar un pedido a la API. Después se le pasa como si lo hubiera dicho ella,
/// así la conversación queda coherente.
const String saludoInicial = 'Ciao! Sono Tuky. Come stai oggi?';

/// La almohadilla que marca un pedido de traducción: #manteca#.
const String marcaTraduccion = '#';

/// Teclas que el teclado propio agrega solo en el chat. La almohadilla es
/// imprescindible (es como se piden las traducciones) y los signos hacen falta
/// para escribir una pregunta.
const List<String> teclasDelChat = ['#', '?', '.', ','];

/// Las instrucciones que se le dan a la IA una sola vez, al principio de cada
/// charla. Están acá y no en la pantalla para poder verificarlas en los tests.
const String promptDeChat = '''
Sos Tuky, un amigo italiano que charla por mensajes con alguien de Argentina
que está aprendiendo italiano. Tenés que seguir estas reglas siempre:

1. Escribí SIEMPRE en italiano simple y de todos los días, con frases cortas.
   Nada de italiano literario ni palabras raras.
2. Contestá poco: dos o tres frases como máximo, y terminá siempre con una
   pregunta para que la charla siga.
3. Lo normal es NO corregir: contestá la charla y listo. La corrección es la
   excepción y va solo cuando escribió algo que un italiano no diría, como un
   verbo mal conjugado, una preposición equivocada o una palabra mal escrita.
   Ahí, y solo ahí, ponela en el primer renglón, con este formato exacto:
   Correzione: la frase bien escrita
   Nunca escribas un renglón de corrección que repita la frase tal como la
   escribió: si la frase está bien, no hay corrección y no va ese renglón.
   Poner el sujeto (io, tu, lui) no es un error: en italiano se puede omitir,
   pero decirlo también está bien. Nunca lo corrijas por eso.
   No expliques la regla ni agregues comentarios sobre la corrección.
4. Todo lo que venga entre almohadillas (#) no es parte de la charla: es un
   pedido de traducción. Puede ser una palabra (#manteca#) o una frase entera
   (#como estas?#). Contestá cada pedido en su propio renglón, arriba de todo,
   con este formato exacto:
   #manteca# = #burro#
5. La traducción va SIEMPRE al otro idioma, nunca al mismo. Fijate primero en
   qué idioma está escrito lo que te dieron:
   - si está en español, traducilo al italiano: #ventana# = #finestra#
   - si está en italiano, traducilo al español: #finestra# = #ventana#
   Nunca devuelvas la misma palabra que te dieron.
6. Si el mensaje es SOLO un pedido de traducción (no hay nada más escrito fuera
   de las almohadillas), contestá únicamente la traducción y nada más: sin
   saludos, sin preguntas, sin comentarios y sin seguir la charla.
   Si además de las almohadillas escribió otra cosa, ahí sí: primero las
   traducciones, después la corrección, y al final tu respuesta a la charla,
   como si el pedido no hubiera pasado.
7. No uses markdown, ni asteriscos, ni emojis, ni listas numeradas: el texto se
   lee en voz alta.
8. Cuando tengas que escribir en español, usá el de Latinoamérica: "ustedes",
   nunca "vosotros".
''';

/// Quién dijo cada mensaje.
enum Quien {
  yo,
  ia,

  /// Un cartel de la app (por ejemplo, que no hubo internet). No se le manda
  /// a la IA: no es parte de la charla.
  aviso,
}

class Mensaje {
  const Mensaje.mia(this.texto) : quien = Quien.yo;
  const Mensaje.deLaIa(this.texto) : quien = Quien.ia;
  const Mensaje.aviso(this.texto) : quien = Quien.aviso;

  final Quien quien;
  final String texto;
}

/// Un pedido de traducción cerrado: '#manteca#'. Una almohadilla sola no
/// cuenta, así que mientras se escribe '#man' todavía no es un pedido.
final RegExp _pedidoCerrado = RegExp(
  '$marcaTraduccion([^$marcaTraduccion]+)$marcaTraduccion',
);

/// Un pedazo de texto, marcado si es un pedido de traducción. El texto del
/// trozo marcado incluye las almohadillas: juntando todos los trozos se vuelve
/// a tener el mensaje tal como se escribió.
typedef TrozoDeTexto = ({String texto, bool marcada});

/// Parte el texto separando los pedidos de traducción del resto.
///
/// 'me falta #manteca#' da dos trozos: 'me falta ' sin marcar y '#manteca#'
/// marcado. Sirve para pintar la traducción distinto sin cambiarle ni una letra
/// al mensaje.
List<TrozoDeTexto> partirPorMarcas(String texto) {
  final trozos = <TrozoDeTexto>[];
  var desde = 0;
  for (final pedido in _pedidoCerrado.allMatches(texto)) {
    if (pedido.start > desde) {
      trozos.add((texto: texto.substring(desde, pedido.start), marcada: false));
    }
    trozos.add((texto: pedido[0]!, marcada: true));
    desde = pedido.end;
  }
  if (desde < texto.length) {
    trozos.add((texto: texto.substring(desde), marcada: false));
  }
  return trozos;
}

/// Lo que se pidió traducir: de 'quiero #manteca# y #pan#' saca
/// ['manteca', 'pan'].
List<String> pedidosDeTraduccion(String texto) => [
      for (final pedido in _pedidoCerrado.allMatches(texto))
        if (pedido[1]!.trim().isNotEmpty) pedido[1]!.trim(),
    ];

/// El texto sin las almohadillas, para leerlo en voz alta: si no, el motor
/// pronunciaría el símbolo.
String sinMarcas(String texto) => texto.replaceAll(marcaTraduccion, '');

/// Cualquier cosa que no sea una letra: espacios, signos, números.
final RegExp _noEsLetra = RegExp(r'[^\p{L}]', unicode: true);

/// True cuando el mensaje es solo un pedido de traducción, sin nada más
/// escrito afuera de las almohadillas.
///
/// Es la diferencia entre las dos formas de usar el chat: '#manteca#' es ir al
/// diccionario y se contesta solo con la traducción, mientras que 'mi serve la
/// #manteca#' es charlar y ahí la charla sigue.
bool esSoloTraduccion(String mensaje) {
  if (pedidosDeTraduccion(mensaje).isEmpty) return false;
  final afuera = partirPorMarcas(mensaje)
      .where((trozo) => !trozo.marcada)
      .map((trozo) => trozo.texto)
      .join();
  return afuera.replaceAll(_noEsLetra, '').isEmpty;
}

/// Cómo empieza el renglón de la corrección. Se acepta con cualquier
/// mayúscula y con espacios antes de los dos puntos.
final RegExp _empiezaCorreccion = RegExp(
  r'^correzione\s*:',
  caseSensitive: false,
);

/// Signos que no cambian lo que dice una frase.
final RegExp _signos = RegExp(r'[.,;:!?¡¿"“”]');
final RegExp _espacios = RegExp(r'\s+');

/// Deja la frase comparable: sin mayúsculas, sin signos y con un solo espacio
/// entre palabras.
///
/// Los acentos y los apóstrofos NO se tocan a propósito: escribir "perche" en
/// vez de "perché", o "l'acqua" en vez de "lacqua", son justamente los errores
/// que la corrección tiene que mostrar.
String _comparable(String texto) => texto
    .toLowerCase()
    .replaceAll(_signos, '')
    .replaceAll(_espacios, ' ')
    .trim();

/// Saca el renglón de corrección cuando corrige con la misma frase que se
/// escribió, que no es una corrección.
///
/// Pasa seguido: las instrucciones le dejan un lugar donde va la corrección y
/// el modelo lo llena aunque la frase esté bien, o repite la charla anterior
/// donde sí había corregido algo. Que se muestre solo cuando de verdad cambió
/// algo no puede depender de que la IA se porte bien.
///
/// Si al sacarlo no queda nada se devuelve la respuesta entera: antes mostrar
/// una corrección al pedo que una burbuja vacía.
String sinCorreccionRepetida(String respuesta, String mensaje) {
  final escrito = _comparable(mensaje);
  final quedan = [
    for (final renglon in respuesta.split('\n'))
      if (!_esCorreccionDe(renglon, escrito)) renglon,
  ];

  final limpio = quedan.join('\n').trim();
  return limpio.isEmpty ? respuesta : limpio;
}

bool _esCorreccionDe(String renglon, String escritoComparable) {
  final texto = renglon.trim();
  final marca = _empiezaCorreccion.matchAsPrefix(texto);
  if (marca == null) return false;
  return _comparable(texto.substring(marca.end)) == escritoComparable;
}

/// Un renglón de traducción: '#manteca# = #burro#'.
final RegExp _renglonTraducido = RegExp(
  '$marcaTraduccion[^$marcaTraduccion]+$marcaTraduccion'
  r'\s*=\s*'
  '$marcaTraduccion[^$marcaTraduccion]+$marcaTraduccion',
);

/// Deja solo los renglones de traducción de la respuesta.
///
/// Las instrucciones ya le piden a la IA que cuando el mensaje sea solo un
/// pedido conteste solo la traducción, pero a veces igual saluda o pregunta
/// algo. Recortarlo acá lo vuelve seguro y no una cuestión de suerte.
///
/// Si no hay ni un renglón con el formato esperado se devuelve la respuesta
/// entera: es mejor mostrar algo raro que no mostrar nada.
String soloLasTraducciones(String respuesta) {
  final renglones = respuesta
      .split('\n')
      .map((renglon) => renglon.trim())
      .where((renglon) => _renglonTraducido.hasMatch(renglon))
      .toList();
  return renglones.isEmpty ? respuesta : renglones.join('\n');
}

/// El mensaje tal como se le manda a la IA.
///
/// Cuando hay un pedido de traducción se le suma un recordatorio del formato.
/// Las instrucciones ya lo explican, pero repetirlo en el turno donde importa
/// es lo que hace que conteste siempre igual, y así la app puede pintar la
/// traducción y leerla en voz alta.
String textoParaLaIa(String mensaje) {
  final pedidos = pedidosDeTraduccion(mensaje);
  if (pedidos.isEmpty) return mensaje;

  final ejemplos = pedidos.map((p) => '#$p# = #(traducción)#').join(', ');
  const direccion = 'Si está en español traducilo al italiano; si está en '
      'italiano traducilo al español. Nunca devuelvas la misma palabra.';

  if (esSoloTraduccion(mensaje)) {
    return '$mensaje\n\n'
        '(Esto es solo un pedido de traducción, no es charla. Contestá '
        'únicamente $ejemplos, un renglón por pedido, y nada más: sin saludos, '
        'sin preguntas y sin comentarios. $direccion)';
  }

  return '$mensaje\n\n'
      '(Recordá: lo que está entre # es un pedido de traducción. Empezá tu '
      'respuesta con $ejemplos, un renglón por pedido, y después seguí la '
      'charla en italiano. $direccion)';
}

/// La charla: los mensajes que se dijeron, en orden.
///
/// Vive mientras se esté en la pestaña del chat. Al salir a otra sección la
/// pantalla se destruye y esta lista se va con ella, así que al volver la IA
/// no se acuerda de nada. Es a propósito: la memoria es solo de esta charla.
class Conversacion {
  final List<Mensaje> mensajes = [const Mensaje.deLaIa(saludoInicial)];

  void agregar(Mensaje mensaje) => mensajes.add(mensaje);

  /// El pedido para la API: las instrucciones, el saludo que ya se vio en
  /// pantalla, y todo lo que se dijeron después.
  ///
  /// Las instrucciones van como primer turno del alumno en vez de por
  /// systemInstruction: es el camino que el modelo lite seguro acepta, y ya
  /// sabemos que un campo de más ahí devuelve 400.
  List<Map<String, dynamic>> contenidos() {
    final dichos = mensajes.where((m) => m.quien != Quien.aviso).toList();

    final turnos = [
      turnoGemini('user', promptDeChat),
      turnoGemini('model', saludoInicial),
    ];

    // Desde 1: el saludo ya está puesto arriba.
    for (var i = 1; i < dichos.length; i++) {
      final mensaje = dichos[i];
      final mio = mensaje.quien == Quien.yo;
      // El recordatorio de las traducciones se le pone solo al último mensaje:
      // en los viejos ya no sirve de nada y ensuciaría el historial.
      final ultimo = i == dichos.length - 1;
      turnos.add(turnoGemini(
        mio ? 'user' : 'model',
        mio && ultimo ? textoParaLaIa(mensaje.texto) : mensaje.texto,
      ));
    }

    return turnos;
  }
}
