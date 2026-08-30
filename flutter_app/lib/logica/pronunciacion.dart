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
/// así que sin esto la palabra daría siempre mal.
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

/// Compara lo que se pidió decir con lo que el celular escuchó.
///
/// Que la palabra aparezca en las alternativas y no en la primera cuenta como
/// [ComoSalio.casi]: el reconocedor la consideró, así que algo se entendió,
/// pero no fue lo primero que le vino.
ComoSalio comparar({required String esperada, required LoEscuchado? oido}) {
  if (oido == null || oido.vacio) return ComoSalio.nada;

  final objetivo = normalizar(esperada);
  if (objetivo.isEmpty) return ComoSalio.nada;
  if (normalizar(oido.mejor) == objetivo) return ComoSalio.bien;

  for (final otra in oido.alternativas) {
    if (normalizar(otra) == objetivo) return ComoSalio.casi;
  }
  return ComoSalio.mal;
}
