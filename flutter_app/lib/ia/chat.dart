import 'dart:math';

import '../logica/diccionario_buscar.dart';


/// De qué charla se trata.
///
/// Las dos las contesta el mismo modelo; lo que cambia es el prompt, y el
/// prompt vive en el servidor. La app solo dice en cuál está: así agregar la
/// farmacia o la estación es agregar un prompt allá, sin publicar un APK.
///
/// Antes, el bar era una charla guionada que vivía en la app: un árbol de
/// respuestas escritas. Andaba sin internet y nunca corregía mal, porque la
/// frase correcta estaba escrita al lado. Pero era siempre la misma, y se
/// terminaba la segunda vez que la hacías.
enum Escena {
  libre,
  bar;

  /// Cómo la nombra el servidor.
  String get paraElServidor => name;

  /// Quién contesta, para el cartel de "está escribiendo".
  String get quienContesta => switch (this) {
        Escena.libre => 'Tuky',
        Escena.bar => 'El barista',
      };

  /// Con qué puede arrancar.
  List<String> get saludos => switch (this) {
        Escena.libre => saludosIniciales,
        Escena.bar => saludosDelBar,
      };

  /// Si esta escena puede darse por terminada. La libre no termina nunca: es
  /// una charla, no una escena.
  bool get termina => this == Escena.bar;
}

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

/// Con qué abre el barista.
///
/// Son todas preguntas: el saludo tiene que dejar al alumno con algo para
/// contestar. Un "Buongiorno!" a secas lo deja mirando la pantalla, y de ahí
/// sale un "buongiorno" de vuelta que no es practicar nada.
const List<String> saludosDelBar = [
  'Buongiorno! Cosa ti porto?',
  'Buongiorno! Cosa prendi?',
  'Buongiorno! Cosa ti preparo?',
  'Buongiorno! Dimmi pure, cosa prendi?',
  'Ciao! Che cosa prendi oggi?',
  'Ciao! Cosa ti faccio?',
  'Buonasera! Cosa ti porto?',
  'Buongiorno! Prendi un caffè?',
  'Ciao! Qualcosa da bere?',
  'Buongiorno! Hai già scelto?',
];

/// Uno de los saludos de esa escena, al azar.
///
/// [distintoDe] es el de la charla que se está dejando: sortear el mismo dos
/// veces seguidas es justo lo que se quiere evitar.
String saludoAlAzar({
  Escena escena = Escena.libre,
  String? distintoDe,
  Random? azar,
}) {
  final posibles = escena.saludos.where((s) => s != distintoDe).toList();
  return posibles[(azar ?? Random()).nextInt(posibles.length)];
}

/// La palabra con la que el barista cierra la escena.
///
/// La pide el prompt del servidor. Va en mayúsculas porque "fine" suelta es
/// una palabra italiana común —el final de algo—, y no se puede confundir una
/// cosa con la otra.
const String marcaDelFinal = 'FINE';

/// La marca, al final del mensaje.
///
/// Se acepta en un renglón aparte, que es como la pide el prompt, y también
/// pegada al final de una frase: el modelo devolvió "Arrivederci. FINE" y
/// pelearle a un modelo por dónde pone una palabra se pierde siempre. Lo que
/// sigue —un punto, un signo— se come con ella.
/// Sin `r''`: una cadena cruda en Dart no interpola, y la marca quedaba
/// buscándose a sí misma escrita con el signo de pesos adelante.
final RegExp _marcaAlFinal = RegExp('(^|\\s)$marcaDelFinal[\\s.!]*\$');

/// True cuando el barista dio la escena por terminada.
bool cierraLaEscena(String respuesta) =>
    _marcaAlFinal.hasMatch(respuesta.trimRight());

/// La respuesta sin la marca: lo que se muestra en pantalla.
String sinLaMarcaDelFinal(String respuesta) =>
    respuesta.trimRight().replaceFirst(_marcaAlFinal, '').trimRight();

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
/// Son tres marcas y no una. "Volevi dire:" es la que pide el servidor;
/// "Correzione:" es la que pedía antes, y aceptarla evita que un celular que
/// no se actualizó se quede sin la red de seguridad.
///
/// La tercera, "volevi decir", es un error del modelo y está acá a
/// propósito: como las instrucciones del servidor están escritas en
/// castellano, se le contagian, y más de una vez devolvió media marca en
/// italiano y media en castellano. Si no se la reconoce, la corrección que
/// repite la frase tal cual se escribió deja de filtrarse y se muestra.
final RegExp _empiezaCorreccion = RegExp(
  r'^(correzione|volevi\s+(dire|decir))\s*:',
  caseSensitive: false,
);

/// Lo que se lee en pantalla donde el modelo escribió "Volevi dire:".
///
/// La marca se le pide en italiano al servidor y así se deja: el modelo la
/// escribe sola y cambiársela sería tocar el prompt para ganar nada. Lo que
/// se cambia es lo que se muestra.
///
/// En castellano porque hace falta distinguir de un vistazo dos cosas que
/// llegan en la misma burbuja: el barista hablándote —que es italiano y hay
/// que leerlo— y el aviso de que lo que escribiste no se dice así. Con las
/// dos en italiano, el aviso se lee como una frase más de la charla.
const String seDiceAsi = 'Se dice así:';

/// Cambia la marca de corrección al castellano, dejando la frase corregida
/// intacta.
///
/// Solo toca el principio del renglón. Lo que sigue es italiano bien dicho y
/// es lo que hay que aprender.
String conLaMarcaEnCastellano(String respuesta) =>
    _conLaMarca(respuesta, (resto) => '$seDiceAsi$resto');

/// Lo mismo para leer en voz alta, pero sin la marca.
///
/// La voz es italiana. Leer "Se dice así" con acento italiano suena a
/// error, y leer "Volevi dire" sería decirle en italiano algo que no es
/// parte de la charla. Se saca y se lee la frase corregida sola, que es lo
/// único que vale la pena escuchar de ese renglón.
String paraLeerEnVozAlta(String respuesta) =>
    _conLaMarca(respuesta, (resto) => resto.trimLeft());

String _conLaMarca(String respuesta, String Function(String) queHacer) => [
      for (final renglon in respuesta.split('\n'))
        _cambiarLaMarca(renglon, queHacer),
    ].join('\n');

String _cambiarLaMarca(String renglon, String Function(String) queHacer) {
  // Los espacios de adelante se guardan: sacarlos movería el renglón.
  final adelante = renglon.length - renglon.trimLeft().length;
  final texto = renglon.trimLeft();
  final marca = _empiezaCorreccion.matchAsPrefix(texto);
  if (marca == null) return renglon;
  return renglon.substring(0, adelante) + queHacer(texto.substring(marca.end));
}

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
  Conversacion({this.escena = Escena.libre, String? saludo, Random? azar})
      : saludo = saludo ?? saludoAlAzar(escena: escena, azar: azar) {
    mensajes.add(Mensaje.deLaIa(this.saludo));
  }

  /// De qué charla se trata. Viaja al servidor, que con eso elige el prompt.
  final Escena escena;

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
