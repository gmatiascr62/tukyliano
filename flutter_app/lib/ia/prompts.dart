import 'dart:math';

import '../constantes.dart';
import 'gemini.dart';

/// Un tema con el vocabulario que se le permite usar al modelo. Sin la lista,
/// las palabras que no son el verbo salen a la lotería y la frase se vuelve
/// difícil por motivos que no tienen nada que ver con la conjugación.
class TemaFrase {
  const TemaFrase(this.nombre, this.palabras);

  final String nombre;
  final List<String> palabras;
}

/// Palabras que sirven para cualquier tema. Van siempre, además de las del
/// tema sorteado.
const List<String> palabrasComunes = [
  'hoy',
  'mañana',
  'ayer',
  'ahora',
  'siempre',
  'nunca',
  'mucho',
  'poco',
  'todo',
  'nada',
  'bien',
  'mal',
  'grande',
  'chico',
  'nuevo',
  'viejo',
  'lindo',
  'acá',
  'temprano',
  'tarde',
];

/// Temas que se sortean en cada frase. La variedad la pone la app: cuando el
/// prompt es siempre igual, el modelo tiende a la respuesta más probable y
/// repite las mismas frases.
const List<TemaFrase> temasFrase = [
  TemaFrase('la casa', [
    'casa', 'puerta', 'ventana', 'cama', 'mesa', 'silla', 'cocina', 'pieza',
    'baño', 'llave', 'luz',
  ]),
  TemaFrase('la comida', [
    'pan', 'agua', 'leche', 'pizza', 'fideos', 'queso', 'fruta', 'manzana',
    'torta', 'comer', 'tomar',
  ]),
  TemaFrase('la escuela', [
    'escuela', 'maestra', 'libro', 'cuaderno', 'lápiz', 'tarea', 'clase',
    'compañero', 'recreo', 'estudiar',
  ]),
  TemaFrase('el trabajo', [
    'trabajo', 'oficina', 'jefe', 'computadora', 'papel', 'reunión', 'plata',
    'hora', 'trabajar',
  ]),
  TemaFrase('la familia', [
    'mamá', 'papá', 'hermano', 'hermana', 'abuela', 'abuelo', 'tío', 'primo',
    'bebé', 'familia',
  ]),
  TemaFrase('los amigos', [
    'amigo', 'amiga', 'plaza', 'juego', 'fiesta', 'charla', 'jugar', 'hablar',
    'salir',
  ]),
  TemaFrase('el clima', [
    'frío', 'calor', 'lluvia', 'sol', 'viento', 'nieve', 'nube', 'paraguas',
    'llover',
  ]),
  TemaFrase('un viaje', [
    'tren', 'colectivo', 'avión', 'valija', 'mapa', 'hotel', 'playa',
    'viajar', 'llegar',
  ]),
  TemaFrase('las mascotas', [
    'perro', 'gato', 'pájaro', 'pelota', 'agua', 'comida', 'jardín',
    'correr', 'dormir',
  ]),
  TemaFrase('los deportes', [
    'fútbol', 'pelota', 'equipo', 'partido', 'cancha', 'gol', 'bici',
    'correr', 'ganar',
  ]),
  TemaFrase('la música', [
    'música', 'canción', 'radio', 'guitarra', 'baile', 'fiesta', 'cantar',
    'bailar', 'escuchar',
  ]),
  TemaFrase('la ropa', [
    'ropa', 'remera', 'pantalón', 'zapatos', 'campera', 'gorra', 'medias',
    'lavar', 'usar',
  ]),
  TemaFrase('el supermercado', [
    'supermercado', 'bolsa', 'plata', 'pan', 'leche', 'fruta', 'lista',
    'comprar', 'pagar',
  ]),
  TemaFrase('la ciudad', [
    'ciudad', 'calle', 'plaza', 'esquina', 'negocio', 'banco', 'gente',
    'caminar', 'cruzar',
  ]),
  TemaFrase('el auto', [
    'auto', 'llave', 'garaje', 'ruta', 'nafta', 'rueda', 'viaje', 'manejar',
    'lavar',
  ]),
  TemaFrase('las vacaciones', [
    'vacaciones', 'playa', 'mar', 'sol', 'campo', 'foto', 'descanso',
    'nadar', 'descansar',
  ]),
  TemaFrase('un cumpleaños', [
    'cumpleaños', 'torta', 'regalo', 'globo', 'vela', 'fiesta', 'amigos',
    'cantar', 'invitar',
  ]),
  TemaFrase('la salud', [
    'médico', 'farmacia', 'remedio', 'cama', 'fiebre', 'dolor', 'agua',
    'descansar', 'curar',
  ]),
  TemaFrase('el teléfono', [
    'teléfono', 'mensaje', 'llamada', 'foto', 'batería', 'pantalla',
    'llamar', 'escribir', 'mirar',
  ]),
  TemaFrase('el fin de semana', [
    'sábado', 'domingo', 'plaza', 'cine', 'película', 'mate', 'siesta',
    'salir', 'descansar',
  ]),
];

/// Ejemplos del largo exacto que se pide: ninguno pasa las cuatro palabras.
const List<String> ejemplosFrase = [
  'Hoy comemos pizza',
  'Mi hermano lava ropa',
  'Mañana voy al trabajo',
  'El perro duerme acá',
  'Compro pan y leche',
  'Mi mamá mira televisión',
  'Hace mucho frío hoy',
  'Los chicos juegan afuera',
  'Tomo el tren temprano',
  'Mi amiga cocina fideos',
];

/// Una frase para practicar: el español que se muestra, el italiano de
/// referencia con el que se corrige y una pista opcional (una palabra clave
/// traducida) que el alumno ve solo si la pide.
class FraseGenerada {
  const FraseGenerada({
    required this.espanol,
    required this.italiano,
    this.pista = '',
  });

  final String espanol;
  final String italiano;
  final String pista;
}

/// Arma el prompt de generación. Está separado del pedido HTTP para poder
/// verificarlo en los tests sin llamar a la API.
String promptGenerarFrase({
  required String verbo,
  required String traduccion,
  required String tiempo,
  required String persona,
  String conjugacionItaliana = '',
  Random? azar,
}) {
  final random = azar ?? Random();
  final etiqueta = etiquetasTiempo[tiempo] ?? tiempo;
  final esGerundio = tiempo == tiempoGerundio;

  // Si tenemos la conjugación cargada en el JSON se la damos ya resuelta: así
  // el modelo no puede escribir el italiano en una persona y el español en
  // otra (pasaba, por ejemplo "Mañana estaré..." con "Domani sarà...").
  final exigenciaVerbo = conjugacionItaliana.isEmpty
      ? ''
      : esGerundio
          ? "En italiano el gerundio tiene que aparecer exactamente "
              "como '$conjugacionItaliana'. "
          : "En italiano el verbo tiene que aparecer conjugado exactamente "
              "como '$conjugacionItaliana'. ";

  // El gerundio no tiene personas, así que no se le pide ninguna.
  final pedido = esGerundio
      ? "que se traduzca al italiano usando el gerundio del verbo "
          "'$verbo' ($traduccion). "
      : "que se traduzca al italiano usando el verbo '$verbo' ($traduccion) "
          "conjugado en $etiqueta, persona '$persona'. ";

  final mismaFrase = esGerundio
      ? "El español y el italiano tienen que ser la misma frase: uno es la "
          "traducción literal del otro. "
      : "El español y el italiano tienen que ser la misma frase, con la misma "
          "persona ('$persona'): uno es la traducción literal del otro. ";

  final tema = temasFrase[random.nextInt(temasFrase.length)];
  final barajados = List.of(ejemplosFrase)..shuffle(random);
  final ejemplos = barajados.take(2).map((e) => "'$e'").join(', ');

  // El vocabulario permitido se limita a propósito: es lo único que hace
  // difícil una frase corta, porque la conjugación ya se la damos hecha.
  final vocabulario = [...palabrasComunes, ...tema.palabras].join(', ');

  return "Generá una oración MUY CORTA en español (máximo 4 palabras), natural, "
      "$pedido"
      "$exigenciaVerbo"
      "$mismaFrase"
      "Tiene que ser una frase simple y concreta del día a día, del estilo "
      "que diría un chico o alguien que recién empieza, con vocabulario "
      "fácil y nada poético, abstracto ni filosófico. "
      "El tema de la frase tiene que ser: ${tema.nombre}. "
      "Fuera del verbo pedido, usá SOLO palabras de esta lista (los artículos, "
      "preposiciones y pronombres son libres): $vocabulario. "
      "No uses nombres propios de personas, ciudades ni marcas. "
      "Si el tema no encaja bien con el verbo, priorizá que la frase suene natural. "
      "Ejemplos del estilo que busco: $ejemplos. "
      "Usá español de Latinoamérica: 'ustedes', nunca 'vosotros'. "
      'Sumá una pista corta: la palabra más difícil de la frase (la que no es '
      'el verbo pedido) con su traducción al italiano, en el formato '
      '"palabra = parola". '
      'Respondé SOLO un JSON válido, sin markdown, con este formato exacto: '
      '{"espanol": "...", "italiano": "...", "pista": "..."}';
}

/// Arma el prompt de corrección.
String promptVerificarFrase({
  required String fraseEs,
  required String italianoReferencia,
  required String respuestaUsuario,
}) {
  return 'Frase en español: "$fraseEs"\n'
      'Traducción de referencia al italiano: "$italianoReferencia"\n'
      'Respuesta del alumno: "$respuestaUsuario"\n\n'
      '¿Es una traducción correcta al italiano (aceptando variantes válidas, '
      'no tiene que ser idéntica a la referencia, pero ojo con errores de '
      'tipeo)? Respondé SOLO la palabra CORRECTO o INCORRECTO.';
}

/// Le pide a Gemini una oración corta en español con su traducción.
Future<FraseGenerada> generarFrase(
  Gemini gemini,
  String apiKey, {
  required String verbo,
  required String traduccion,
  required String tiempo,
  required String persona,
  String conjugacionItaliana = '',
}) async {
  final prompt = promptGenerarFrase(
    verbo: verbo,
    traduccion: traduccion,
    tiempo: tiempo,
    persona: persona,
    conjugacionItaliana: conjugacionItaliana,
  );
  final datos = extraerJson(await gemini.preguntar(prompt, apiKey));
  return FraseGenerada(
    espanol: datos['espanol'] as String,
    italiano: datos['italiano'] as String,
    // La pista es opcional: si el modelo no la manda, el botón no aparece.
    pista: (datos['pista'] as String?)?.trim() ?? '',
  );
}

/// Le pregunta a Gemini si la traducción del alumno es válida. Acepta
/// variantes correctas: no exige que sea idéntica a la referencia.
Future<bool> verificarFrase(
  Gemini gemini,
  String apiKey, {
  required String fraseEs,
  required String italianoReferencia,
  required String respuestaUsuario,
}) async {
  final prompt = promptVerificarFrase(
    fraseEs: fraseEs,
    italianoReferencia: italianoReferencia,
    respuestaUsuario: respuestaUsuario,
  );
  final texto = (await gemini.preguntar(prompt, apiKey)).trim().toUpperCase();
  return texto.startsWith('CORRECTO');
}
