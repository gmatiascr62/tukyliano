import '../constantes.dart';

/// Una frase con un hueco donde falta la preposición.
class FrasePreposicion {
  const FrasePreposicion({
    required this.frase,
    required this.correcta,
    required this.espanol,
    required this.opciones,
    this.explicacion = '',
  });

  /// La frase italiana con [hueco] en el lugar que falta: "Vado ___ città".
  final String frase;

  /// Lo que va en el hueco: "in", "al", "nella", "per la".
  final String correcta;

  /// La traducción. No es un adorno: sin ella muchas frases tienen dos
  /// respuestas válidas ("parlo ai ragazzi" y "parlo dei ragazzi" son las
  /// dos correctas, y solo el español dice cuál se pide).
  final String espanol;

  /// Los botones que se ofrecen. Van elegidos a mano frase por frase: no son
  /// al azar, son los errores que el español empuja a cometer.
  final List<String> opciones;

  final String explicacion;

  /// La frase ya completa, con la palabra puesta en el hueco.
  String conRespuesta(String palabra) => frase.replaceFirst(hueco, palabra);

  /// La frase bien contestada.
  String get resuelta => conRespuesta(correcta);

  /// Lo que va antes y después del hueco, para poder pintar el medio de otro
  /// color sin volver a partir el texto en la pantalla.
  (String, String) get partes {
    final corte = frase.indexOf(hueco);
    if (corte < 0) return (frase, '');
    return (frase.substring(0, corte), frase.substring(corte + hueco.length));
  }

  static FrasePreposicion? desdeJson(Map<String, dynamic> json) {
    final frase = json['frase'] as String? ?? '';
    final correcta = json['correcta'] as String? ?? '';
    final opciones = (json['opciones'] as List?)?.whereType<String>().toList() ??
        const <String>[];

    // Sin hueco no hay nada que completar, y si la correcta no está entre los
    // botones la frase es imposible de contestar. En los dos casos se
    // descarta en vez de romper la pantalla; un test avisa si pasa.
    if (!frase.contains(hueco) ||
        correcta.isEmpty ||
        !opciones.contains(correcta)) {
      return null;
    }

    return FrasePreposicion(
      frase: frase,
      correcta: correcta,
      espanol: json['es'] as String? ?? '',
      opciones: opciones,
      explicacion: json['explicacion'] as String? ?? '',
    );
  }
}

/// Todo lo que trae preposizioni.json.
class DatosPreposizioni {
  const DatosPreposizioni({required this.version, required this.frases});

  final int version;
  final List<FrasePreposicion> frases;

  static const vacio = DatosPreposizioni(version: 0, frases: []);

  static DatosPreposizioni desdeJson(Map<String, dynamic> json) {
    final frases = <FrasePreposicion>[];
    final lista = json['frases'];
    if (lista is List) {
      for (final item in lista) {
        if (item is! Map<String, dynamic>) continue;
        final frase = FrasePreposicion.desdeJson(item);
        if (frase != null) frases.add(frase);
      }
    }

    return DatosPreposizioni(
      version: json['version'] as int? ?? 0,
      frases: frases,
    );
  }
}
