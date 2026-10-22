import 'dart:math';


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

/// Las instrucciones que se le dan al modelo al principio de cada charla.
///
/// Están en italiano, que es el idioma en el que tiene que contestar: medido
/// contra las mismas instrucciones en castellano y en inglés, son las que dan
/// las respuestas más naturales y más cortas.
///
/// Lo que NO dicen es tan importante como lo que dicen:
///
/// - **No le piden que corrija.** Se midió: a "Ho mangiato la pizza oggi", que
///   está bien escrita, inventó tres correcciones distintas con tres formas de
///   pedírselo, y las tres estaban mal. Una corrección equivocada enseña mal y
///   con autoridad. Corregir lo hace [revisarItaliano], que es código que se
///   puede probar.
/// - **No le dan órdenes numeradas.** La regla "Contestá en italiano simple, de
///   una a tres frases cortas" la leía como el pedido del alumno y contestaba
///   "Ecco una frase corta in italiano: ...". Describirle cómo habla, en vez de
///   darle una lista de tareas, no se confunde con un pedido.
/// - **No le dejan ningún molde para copiar.** Lo que haya entre comillas en
///   las instrucciones, un modelo chico lo escribe tal cual.
///
/// Lo que sí llevan es una charla de ejemplo, y es lo que hace que no salte de
/// tema. Antes pasaba del fútbol al cine y del cine al fin de semana en tres
/// mensajes: la instrucción le pedía "terminá con una pregunta" y él entendía
/// "una pregunta nueva". Explicárselo —"quedate en el tema"— no alcanzó;
/// mostrárselo sí. Medido sobre tres charlas: con la explicación se quedó en
/// el tema una vez de tres, con el ejemplo tres de tres. Es lo mismo que pasa
/// con las traducciones: a un modelo chico se le muestra, no se le describe.
///
/// El ejemplo habla de una bicicleta y no de un perro —que fue el primero que
/// se probó— porque uno de los saludos pregunta por mascotas. Cuando la charla
/// caía justo en el tema del ejemplo, el modelo contestaba con el libreto en
/// vez de con lo que le estaban diciendo. Ningún saludo habla de bicicletas.
///
/// Las instrucciones se prueban en el workflow "Probar el modelo", que las saca
/// de acá y las corre con tres mensajes de alumno.
const String promptDeChat = '''
Sei Tuky, un insegnante di italiano. Il tuo studente parla spagnolo e sta
facendo pratica di conversazione con te.

Rispondi sempre in italiano, mai in spagnolo, con una o due frasi brevi, e
finisci con una domanda sulla stessa cosa che ha appena detto lo studente.

Così parli:

Studente: Ho una bicicletta.
Tuky: Che bello! Di che colore è la tua bicicletta?
Studente: È rossa.
Tuky: Il rosso mi piace molto. Da quanto tempo ce l'hai?
Studente: Da due anni.
Tuky: Due anni non sono pochi! Dove vai di solito in bicicletta?

Non annunciare mai quello che stai per dire: dillo e basta.
Non correggere lo studente: non è il tuo compito.
Niente markdown, niente emoji, niente elenchi.''';

/// Las instrucciones para traducir, que son otras.
///
/// Un pedido de traducción no es una charla: no va saludo, ni pregunta, ni
/// corrección. Mandarle al modelo las reglas de la charla para traducir una
/// palabra es lo que antes hacía que contestara "burro! E tu, cosa mangi?".
///
/// Los dos ejemplos de adentro valen más que cualquier explicación: a un modelo
/// chico se le muestra el formato, no se le describe.
const String promptDeTraduccion = '''
Traducís palabras y frases entre español e italiano.
Si te dan una palabra en español, contestás la italiana; si te dan una
italiana, contestás la española. Nunca devolvés la misma palabra.
Contestás solo con la traducción: sin comillas, sin explicar y sin saludar.''';

/// Cuántos mensajes de la charla se le recuerdan al modelo.
///
/// Ocho son cuatro idas y vueltas. Cada mensaje que se suma son tokens que el
/// celular tiene que volver a procesar en cada respuesta: con el contexto de
/// 1024 tokens que se le da al modelo, pasarse significa que se corta solo por
/// el medio. Para una charla de práctica, acordarse de las últimas cuatro
/// vueltas alcanza.
const int cuantosMensajesSeRecuerdan = 8;

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

/// Saca del texto del modelo cualquier renglón de corrección.
///
/// Al modelo ya no se le pide que corrija: se le pide que converse. Corregir
/// lo hacen las reglas de reglas_italiano.dart, que son código que se puede
/// probar. Así que si igual aparece un "Correzione:", es algo que inventó, y
/// se saca.
///
/// No es exageración. A "Ho mangiato la pizza oggi", que está bien escrita, se
/// le midieron estas tres correcciones con tres formas distintas de pedírselo:
/// "C'è stata un'impresa nuova?", "Hai mangiato la pizza oggi" —le cambió la
/// persona— y "Hai mangiato una pizza?". Una corrección equivocada enseña mal,
/// y encima con autoridad.
String sinCorreccionesDelModelo(String respuesta) {
  final quedan = [
    for (final renglon in respuesta.split('\n'))
      if (_empiezaCorreccion.matchAsPrefix(renglon.trim()) == null) renglon,
  ];
  return quedan.join('\n').trim();
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

/// Las marcas con las que Qwen3 separa los turnos. Es el formato ChatML: el
/// modelo fue entrenado con esto y escribir el prompt de otra manera lo hace
/// contestar cualquier cosa.
const String _turnoAbre = '<|im_start|>';
const String _turnoCierra = '<|im_end|>';

String _turno(String quien, String texto) =>
    '$_turnoAbre$quien\n$texto$_turnoCierra\n';

/// El prompt completo de una charla, listo para darle al modelo.
///
/// Lleva las instrucciones, el saludo con el que arrancó la charla y los
/// últimos [cuantosMensajesSeRecuerdan] mensajes. Termina abriendo el turno del
/// profesor, que es la forma de decirle "ahora escribís vos".
String promptDeLaCharla({
  required String saludo,
  required List<Mensaje> mensajes,
  int cuantosRecordar = cuantosMensajesSeRecuerdan,
}) {
  // Los avisos de la app (que se cortó la luz, que no hay memoria) no son
  // parte de la charla: si se le mandaran, el modelo los leería como si los
  // hubiera escrito el alumno.
  final dichos = mensajes.where((m) => m.quien != Quien.aviso).toList();

  // El primero es el saludo y va siempre, aunque la charla sea larga: es lo
  // que le recuerda al modelo de qué tema estaban hablando.
  final cuerpo = dichos.isEmpty ? <Mensaje>[] : dichos.sublist(1);
  final recordados = cuerpo.length <= cuantosRecordar
      ? cuerpo
      : cuerpo.sublist(cuerpo.length - cuantosRecordar);

  final texto = StringBuffer()
    ..write(_turno('system', promptDeChat))
    ..write(_turno('assistant', saludo));

  for (final mensaje in recordados) {
    texto.write(_turno(
      mensaje.quien == Quien.yo ? 'user' : 'assistant',
      mensaje.texto,
    ));
  }

  return '$texto${_turnoAbre}assistant\n';
}

/// El prompt para traducir una palabra o una frase.
///
/// Los dos ejemplos de adentro no están de adorno: son lo que hace que un
/// modelo de 0.6B conteste "burro" y no "La traducción de manteca es burro,
/// ¿querés saber más?".
///
/// Y son dos, uno para cada lado, porque de ahí sale también hacia dónde
/// traducir. Se probó adivinar el idioma con reglas —tildes, dobles
/// consonantes, en qué letra termina— y no alcanza: "ventana" y "finestra"
/// se escriben parecido y la regla fallaba la mitad de las veces. Los ejemplos
/// se lo enseñan mejor de lo que una regla lo adivina.
String promptDeLaTraduccion(String pedido) {
  return '${_turno('system', promptDeTraduccion)}'
      '${_turno('user', 'Traducí al otro idioma: manteca')}'
      '${_turno('assistant', 'burro')}'
      '${_turno('user', 'Traducí al otro idioma: finestra')}'
      '${_turno('assistant', 'ventana')}'
      '${_turno('user', 'Traducí al otro idioma: $pedido')}'
      '${_turnoAbre}assistant\n';
}

/// Lo que el modelo escribió, listo para mostrar.
///
/// Saca tres cosas que no son la respuesta: el bloque de razonamiento de Qwen3
/// (que aparece igual de vez en cuando, aunque se le pida que no piense), las
/// marcas de turno de ChatML que a veces se le escapan, y los espacios de los
/// bordes.
String limpiarRespuesta(String crudo) {
  var texto = crudo.replaceAll(
    RegExp(r'<think>.*?</think>', dotAll: true),
    '',
  );
  // Un <think> sin cerrar quiere decir que se quedó pensando y lo cortamos:
  // de ahí para adelante no hay respuesta que mostrar.
  final pensandoTodavia = texto.indexOf('<think>');
  if (pensandoTodavia >= 0) texto = texto.substring(0, pensandoTodavia);

  for (final marca in [_turnoCierra, _turnoAbre, '<|endoftext|>']) {
    final corte = texto.indexOf(marca);
    if (corte >= 0) texto = texto.substring(0, corte);
  }

  // Las instrucciones llevan una charla de ejemplo donde cada turno empieza
  // con "Tuky:" o "Studente:". Un modelo chico copia lo que ve, así que puede
  // arrancar la respuesta con su propio nombre.
  texto = texto.trimLeft().replaceFirst(_seAnunciaSolo, '');

  return texto.trim();
}

/// Cuando empieza diciendo quién habla, como en el ejemplo que se le dio.
final RegExp _seAnunciaSolo = RegExp(
  r'^(tuky|studente|assistente|insegnante)\s*:\s*',
  caseSensitive: false,
);

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

  /// El prompt de esta charla, listo para el modelo.
  String prompt() => promptDeLaCharla(saludo: saludo, mensajes: mensajes);
}
