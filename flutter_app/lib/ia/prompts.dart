import 'dart:math';

import '../constantes.dart';
import 'gemini.dart';

/// Temas y ejemplos que se sortean en cada frase. La variedad la pone la app:
/// cuando el prompt es siempre igual, el modelo tiende a la respuesta más
/// probable y repite las mismas frases.
const List<String> temasFrase = [
  'la casa',
  'la comida',
  'la escuela',
  'el trabajo',
  'la familia',
  'los amigos',
  'el clima',
  'un viaje',
  'las mascotas',
  'los deportes',
  'la música',
  'la ropa',
  'el supermercado',
  'la ciudad',
  'el auto',
  'las vacaciones',
  'un cumpleaños',
  'la salud',
  'el teléfono',
  'el fin de semana',
];

const List<String> ejemplosFrase = [
  'Hoy comemos pizza',
  'Mi hermano lava el auto',
  'Mañana voy al trabajo',
  'El perro duerme en el sillón',
  'Compro pan en la esquina',
  'Mi mamá mira televisión',
  'Hace mucho frío hoy',
  'Los chicos juegan al fútbol',
  'Tomo el tren temprano',
  'Mi amiga cocina fideos',
];

/// Una frase para practicar: el español que se muestra y el italiano de
/// referencia con el que se corrige.
class FraseGenerada {
  const FraseGenerada({required this.espanol, required this.italiano});

  final String espanol;
  final String italiano;
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

  return "Generá una oración MUY CORTA en español (máximo 6 palabras), natural, "
      "$pedido"
      "$exigenciaVerbo"
      "$mismaFrase"
      "Tiene que ser una frase simple y concreta del día a día, del estilo "
      "que diría un chico o alguien que recién empieza, con vocabulario "
      "fácil y nada poético, abstracto ni filosófico. "
      "El tema de la frase tiene que ser: $tema. "
      "Si el tema no encaja bien con el verbo, priorizá que la frase suene natural. "
      "Ejemplos del estilo que busco: $ejemplos. "
      "Usá español de Latinoamérica: 'ustedes', nunca 'vosotros'. "
      'Respondé SOLO un JSON válido, sin markdown, con este formato exacto: '
      '{"espanol": "...", "italiano": "..."}';
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
