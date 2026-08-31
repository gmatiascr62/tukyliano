import '../datos/escucha.dart';

/// Cómo salió el intento de decir una palabra.
enum ComoSalio {
  /// El reconocedor entendió justo la palabra.
  bien,

  /// La entendió, pero como segunda opción: se entiende, aunque no clarísimo.
  casi,

  /// Entendió otra cosa.
  mal,

  /// No llegó a escuchar nada.
  nada,
}

/// Los números que el reconocedor devuelve como cifra.
///
/// Es el caso más molesto: se dice "cinque" perfecto y Android escribe "5",
/// así que sin esto la palabra daría siempre mal. Llegan hasta el 30, que es
/// hasta donde se practican.
const Map<String, String> numerosEnLetras = {
  '0': 'zero',
  '1': 'uno',
  '2': 'due',
  '3': 'tre',
  '4': 'quattro',
  '5': 'cinque',
  '6': 'sei',
  '7': 'sette',
  '8': 'otto',
  '9': 'nove',
  '10': 'dieci',
  '11': 'undici',
  '12': 'dodici',
  '13': 'tredici',
  '14': 'quattordici',
  '15': 'quindici',
  '16': 'sedici',
  '17': 'diciassette',
  '18': 'diciotto',
  '19': 'diciannove',
  '20': 'venti',
  '21': 'ventuno',
  '22': 'ventidue',
  // Sin tilde a propósito: acá se compara contra texto ya normalizado, y
  // "ventitré" pierde la tilde antes de llegar.
  '23': 'ventitre',
  '24': 'ventiquattro',
  '25': 'venticinque',
  '26': 'ventisei',
  '27': 'ventisette',
  '28': 'ventotto',
  '29': 'ventinove',
  '30': 'trenta',
};

const Map<String, String> _sinTilde = {
  'à': 'a',
  'á': 'a',
  'è': 'e',
  'é': 'e',
  'ì': 'i',
  'í': 'i',
  'ò': 'o',
  'ó': 'o',
  'ù': 'u',
  'ú': 'u',
};

final RegExp _sirve = RegExp(r"[a-z0-9']");

/// Deja el texto como para poder compararlo: sin mayúsculas, sin tildes, sin
/// puntuación y con los números escritos con letras.
///
/// Hace falta porque el reconocedor devuelve la frase como la escribiría una
/// persona ("Cinque, per favore.") y acá solo importan las palabras.
String normalizar(String texto) {
  final letras = StringBuffer();
  for (final letra in texto.toLowerCase().split('')) {
    final limpia = _sinTilde[letra] ?? letra;
    letras.write(_sirve.hasMatch(limpia) ? limpia : ' ');
  }

  final palabras = [
    for (final palabra in letras.toString().split(' '))
      if (palabra.isNotEmpty) numerosEnLetras[palabra] ?? palabra,
  ];
  return palabras.join(' ');
}

/// El texto normalizado, partido en palabras.
List<String> enPalabras(String texto) {
  final limpio = normalizar(texto);
  return limpio.isEmpty ? const [] : limpio.split(' ');
}

/// Cuántas palabras seguidas, contando desde el principio, ya se dijeron bien.
///
/// Sirve para ir pintando de verde una frase mientras se la dice. Se avanza
/// solo cuando llega la palabra que toca, así que decir otra cosa no adelanta;
/// y se saltean las que el reconocedor mete de más, que pasa seguido mientras
/// va corrigiendo lo que escribió.
int cuantasSeguidas({required String esperada, required String oido}) {
  final faltan = enPalabras(esperada);
  if (faltan.isEmpty) return 0;

  var van = 0;
  for (final dicha in enPalabras(oido)) {
    if (van >= faltan.length) break;
    if (dicha == faltan[van]) van++;
  }
  return van;
}

/// Compara lo que se pidió decir con lo que el celular escuchó.
///
/// Que aparezca en las alternativas y no en la primera cuenta como
/// [ComoSalio.casi]: el reconocedor lo consideró, así que algo se entendió,
/// pero no fue lo primero que le vino.
ComoSalio comparar({required String esperada, required LoEscuchado? oido}) {
  if (oido == null || oido.vacio) return ComoSalio.nada;

  final cuantas = enPalabras(esperada).length;
  if (cuantas == 0) return ComoSalio.nada;

  if (cuantasSeguidas(esperada: esperada, oido: oido.mejor) == cuantas) {
    return ComoSalio.bien;
  }
  for (final otra in oido.alternativas) {
    if (cuantasSeguidas(esperada: esperada, oido: otra) == cuantas) {
      return ComoSalio.casi;
    }
  }
  return ComoSalio.mal;
}
