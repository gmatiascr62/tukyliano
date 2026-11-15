import 'dart:math';

import '../logica/diccionario_buscar.dart';


/// Con qué puede arrancar la charla, uno por tema.
///
/// No los escribe la IA: los escribimos nosotros para que la charla empiece sin
/// gastar un pedido a la API. Después se le pasa el elegido como si lo hubiera
/// dicho ella, así la conversación queda coherente.
///
/// Son varios porque con uno solo la charla arrancaba siempre igual —«come stai
/// oggi?»— y de ahí salía siempre la misma conversación. Cada uno abre un tema
/// distinto, que es lo que de verdad cambia de qué se habla.
const List<String> saludosIniciales = [
  'Ciao! Sono Tuky. Come stai oggi?',
  'Ciao! Sono Tuky. Cosa hai mangiato oggi?',
  'Ciao! Sono Tuky. Cosa fai questo fine settimana?',
  'Ciao! Sono Tuky. Che tempo fa da te oggi?',
  'Ciao! Sono Tuky. Che lavoro fai?',
  'Ciao! Sono Tuky. Che musica ascolti?',
  'Ciao! Sono Tuky. Sei mai stato in Italia?',
  'Ciao! Sono Tuky. Hai fratelli o sorelle?',
  'Ciao! Sono Tuky. Hai un animale in casa?',
  'Ciao! Sono Tuky. Cosa prendi a colazione?',
  'Ciao! Sono Tuky. Guardi il calcio? Per che squadra tifi?',
  'Ciao! Sono Tuky. Che film hai visto ultimamente?',
  'Ciao! Sono Tuky. Ti piace cucinare?',
  'Ciao! Sono Tuky. Come si chiama la tua città?',
  'Ciao! Sono Tuky. Cosa fai stasera?',
  'Ciao! Sono Tuky. Ti alzi presto la mattina?',
  'Ciao! Sono Tuky. Preferisci il mare o la montagna?',
  'Ciao! Sono Tuky. Stai leggendo un libro in questo periodo?',
  'Ciao! Sono Tuky. Da quanto tempo studi italiano?',
  'Ciao! Sono Tuky. Bevi il mate tutti i giorni?',
  'Ciao! Sono Tuky. Qual è il tuo piatto preferito?',
  'Ciao! Sono Tuky. Ti piace camminare per la città?',
  'Ciao! Sono Tuky. Cosa hai fatto ieri?',
  'Ciao! Sono Tuky. Hai programmi per le vacanze?',
  'Ciao! Sono Tuky. Preferisci il caffè o il tè?',
  'Ciao! Sono Tuky. Che cosa fai nel tempo libero?',
];

/// Uno de los saludos, al azar.
///
/// [distintoDe] es el de la charla que se está dejando: sortear el mismo dos
/// veces seguidas es justo lo que se quiere evitar.
String saludoAlAzar({String? distintoDe, Random? azar}) {
  final posibles = saludosIniciales.where((s) => s != distintoDe).toList();
  return posibles[(azar ?? Random()).nextInt(posibles.length)];
}

/// La almohadilla que marca un pedido de traducción: #manteca#.
const String marcaTraduccion = '#';

// Las instrucciones de Tuky ya no están acá: viven en el servidor, en
// servidor/src/prompt.js.
//
// Se mudaron porque tener dos copias es tener una vieja. La de acá quedó
// congelada en nueve reglas mientras la otra cambiaba, y cuando el servidor
// se publicó por primera vez le estaba pidiendo al modelo que tradujera
// cosas que la app ya resuelve sola con el diccionario.
//
// Y ahora, además, ajustarlas no necesita publicar un APK: se cambia el
// archivo del servidor y lo ven todos al instante.

/// Quién dijo cada mensaje.
enum Quien {
  yo,
  ia,

  /// Un cartel de la app (por ejemplo, que no hubo internet). No se le manda
  /// a la IA: no es parte de la charla.
  aviso,
}

class Mensaje {
  const Mensaje.mia(this.texto, {this.paraLaIa = true}) : quien = Quien.yo;
  const Mensaje.deLaIa(this.texto)
      : quien = Quien.ia,
        paraLaIa = true;

  /// Una traducción contestada por el diccionario de la app.
  ///
  /// Se ve igual que una respuesta de la IA, pero no se le manda: ir al
  /// diccionario no es parte de la charla, y meterlo en el historial haría
  /// que la IA empezara a imitar el formato o a creer que se habló de eso.
  const Mensaje.delDiccionario(this.texto)
      : quien = Quien.ia,
        paraLaIa = false;

  const Mensaje.aviso(this.texto)
      : quien = Quien.aviso,
        paraLaIa = false;

  final Quien quien;
  final String texto;

  /// Si este mensaje forma parte de lo que la IA tiene que recordar.
  final bool paraLaIa;
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
///
/// Son dos marcas y no una porque el servidor pide "Volevi dire:" y la app
/// todavía puede hablar con un modelo que diga "Correzione:". Aceptar las dos
/// cuesta una palabra más en la expresión y evita que un celular que no se
/// actualizó se quede sin la red de seguridad.
final RegExp _empiezaCorreccion = RegExp(
  r'^(correzione|volevi\s+dire)\s*:',
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

/// El mensaje tal como se le manda a la IA.
///
/// Sin las almohadillas. Las traducciones las contesta el diccionario que
/// viaja en la app, así que la IA no tiene que enterarse de que existen: ve
/// una frase normal y sigue la charla.
///
/// Antes esto le mandaba, además del mensaje, un recordatorio del formato en
/// cada turno, porque tres de las nueve reglas del prompt eran sobre las
/// almohadillas y aun así se equivocaba. Esas tres reglas ya no están.
String textoParaLaIa(String mensaje) => sinMarcas(mensaje);

/// Los renglones de traducción que se muestran arriba de la respuesta.
///
/// Salen del diccionario, no de la IA: son instantáneos, andan sin internet
/// y contestan siempre lo mismo.
String renglonesDeTraduccion(List<Traduccion> traducciones) => [
      for (final t in traducciones)
        '$marcaTraduccion${t.pedido}$marcaTraduccion = '
            '$marcaTraduccion${t.comoSeDice}$marcaTraduccion',
    ].join('\n');

/// Lo que se muestra cuando una palabra no está en el diccionario.
String noEstaEnElDiccionario(String pedido) =>
    '$marcaTraduccion$pedido$marcaTraduccion no está en el diccionario.';

/// La charla: los mensajes que se dijeron, en orden.
///
/// Vive mientras se esté en la pestaña del chat. Al salir a otra sección la
/// pantalla se destruye y esta lista se va con ella, así que al volver la IA
/// no se acuerda de nada. Es a propósito: la memoria es solo de esta charla.
class Conversacion {
  Conversacion({String? saludo, Random? azar})
      : saludo = saludo ?? saludoAlAzar(azar: azar) {
    mensajes.add(Mensaje.deLaIa(this.saludo));
  }

  /// Con cuál de los saludos arrancó esta charla. Se guarda porque es el primer
  /// turno que se le manda a la IA: si no coincidiera con el que se ve en
  /// pantalla, la charla que ella recuerda no sería la que se está teniendo.
  final String saludo;

  final List<Mensaje> mensajes = [];

  void agregar(Mensaje mensaje) => mensajes.add(mensaje);

  /// La charla en el formato que espera el servidor propio.
  ///
  /// El saludo va aparte —el servidor lo recibe por su cuenta—, así que acá
  /// van los que vinieron después. Lo que no es para la IA no viaja: buscar
  /// una palabra en el diccionario no es parte de la charla.
  List<Map<String, String>> paraElServidor() {
    final dichos = mensajes.where((m) => m.paraLaIa).toList();

    return [
      for (var i = 1; i < dichos.length; i++)
        if (dichos[i].quien == Quien.yo)
          {'quien': 'yo', 'texto': textoParaLaIa(dichos[i].texto)}
        else
          {'quien': 'ia', 'texto': dichos[i].texto},
    ];
  }
}
