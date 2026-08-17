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
3. Si lo que escribió tiene un error de italiano, corregilo en el primer
   renglón, con este formato exacto y en un solo renglón:
   Correzione: la frase bien escrita
   Si no hay errores, no pongas ninguna corrección. No expliques la regla.
4. Todo lo que venga entre almohadillas (#) no es parte de la charla: es un
   pedido de traducción. Puede ser una palabra (#manteca#) o una frase entera
   (#como estas?#). Contestá cada pedido en su propio renglón, arriba de todo,
   con este formato exacto:
   #manteca# = #burro#
   Si lo que está entre # está en español, traducilo al italiano; si está en
   italiano, traducilo al español. Después de las traducciones seguí la charla
   normalmente en italiano, como si el pedido no hubiera pasado.
5. El orden es: primero las traducciones, después la corrección, y al final tu
   respuesta a la charla.
6. No uses markdown, ni asteriscos, ni emojis, ni listas numeradas: el texto se
   lee en voz alta.
7. Cuando tengas que escribir en español, usá el de Latinoamérica: "ustedes",
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
  return '$mensaje\n\n'
      '(Recordá: lo que está entre # es un pedido de traducción. Empezá tu '
      'respuesta con $ejemplos, un renglón por pedido, y después seguí la '
      'charla en italiano.)';
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
