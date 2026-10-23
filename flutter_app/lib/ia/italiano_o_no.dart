/// Para darse cuenta de cuándo el modelo contestó en castellano.
///
/// Pasa, y es lo peor que puede pasar en una app para practicar italiano. Se
/// midió: a "Ciao tuky, io sono Matías, io ho una sorella" el modelo contestó
/// "¡Hola Matías! Yo también tengo una hermana. ¿A qué edad es ella?", entera
/// en castellano. Lo dispara el nombre propio, que es castellano y lo arrastra.
///
/// Pedírselo en las instrucciones no alcanzó —se probó y siguió pasando— así
/// que esto se decide en código, que es lo único que se puede probar.
///
/// El criterio es al revés de lo que parece: no busca si **parece** castellano
/// sino si tiene algo que en italiano **no existe**. Las dos lenguas comparten
/// demasiado como para andar adivinando, y marcar como castellano una
/// respuesta italiana sería peor que dejar pasar una castellana.
library;

/// Signos y letras que el italiano no usa nunca.
///
/// Los signos de apertura son de la ortografía castellana, la eñe no existe en
/// italiano, y de los acentos, el italiano usa à è é ì ò ù: nunca á í ú.
final RegExp _letrasQueElItalianoNoTiene = RegExp(r'[¿¡ñáíúÁÍÚÑ]');

/// Palabras que existen en castellano y no en italiano.
///
/// Cortas y comunes, para que alcance con que aparezcan dos. Ninguna de estas
/// es una palabra italiana: "hola" en italiano es ciao, "pero" es ma, "mucho"
/// es molto. Van en minúscula y se comparan contra la respuesta en minúscula.
const List<String> _palabrasQueNoSonItalianas = [
  'hola',
  'gracias',
  'pero',
  'mucho',
  'muy',
  'tengo',
  'tienes',
  'eres',
  'estoy',
  'está',
  'también',
  'hermana',
  'hermano',
  'trabajo',
  'siempre',
  'ahora',
  'entonces',
  'porque',
  'cuando',
  'donde',
  'años',
  'ella',
  'ellos',
  'nosotros',
  'ustedes',
  'bueno',
  'puedes',
  'quieres',
];

/// Cuántas palabras castellanas hacen falta para dar por castellana la
/// respuesta.
///
/// Dos y no una: "pero" sola podría ser un nombre o una palabra suelta adentro
/// de una frase italiana, y una respuesta italiana con un tropiezo es mejor
/// que ninguna respuesta.
const int cuantasPalabrasDelante = 2;

/// True si la respuesta está en castellano y no en italiano.
bool contestoEnCastellano(String respuesta) {
  if (respuesta.trim().isEmpty) return false;

  // Un solo signo de apertura o una eñe ya alcanza: en italiano no aparecen
  // nunca, ni por error de tipeo.
  if (_letrasQueElItalianoNoTiene.hasMatch(respuesta)) return true;

  final palabras = respuesta
      .toLowerCase()
      .split(RegExp(r"[^a-záéíóúüñ']+"))
      .where((palabra) => palabra.isNotEmpty)
      .toSet();

  final cuantas =
      _palabrasQueNoSonItalianas.where(palabras.contains).length;
  return cuantas >= cuantasPalabrasDelante;
}
