import '../constantes.dart';

/// Una frase con un hueco donde falta la partícula (o el verbo que la lleva).
///
/// Es el mismo molde para las tres secciones nuevas —via, ci y ne—: cambia el
/// JSON, no la forma. Por eso la clase no se llama "via".
class FraseParticella {
  const FraseParticella({
    required this.frase,
    required this.correcta,
    required this.espanol,
    required this.opciones,
    this.explicacion = '',
    this.persona = '',
  });

  /// La frase italiana con [hueco] en el lugar que falta: "___ via, è tardi".
  final String frase;

  /// Lo que va en el hueco: "Vado", "buttato", "mandatelo".
  final String correcta;

  /// La traducción, que es la consigna de verdad: sin ella "___ via il cane"
  /// admite «porto», «butto» y «mando», y las tres son italiano correcto.
  final String espanol;

  /// Los botones que se ofrecen. Van elegidos a mano frase por frase: son los
  /// otros verbos que también pegan con «via», que es justo la confusión.
  final List<String> opciones;

  final String explicacion;

  /// Qué persona practica la frase (io, tu, lui, noi, voi, loro, o "-" para
  /// las expresiones fijas). No se muestra: está para que un test verifique
  /// que las frases no se queden todas en la primera persona.
  final String persona;

  /// La frase ya completa, con la palabra puesta en el hueco. Es lo que hay
  /// que escribir en el modo de escribir.
  String get resuelta => frase.replaceFirst(hueco, correcta);

  /// Lo que va antes y después del hueco, para pintar el medio de otro color
  /// sin volver a partir el texto en la pantalla.
  (String, String) get partes {
    final corte = frase.indexOf(hueco);
    if (corte < 0) return (frase, '');
    return (frase.substring(0, corte), frase.substring(corte + hueco.length));
  }

  static FraseParticella? desdeJson(Map<String, dynamic> json) {
    final frase = json['frase'] as String? ?? '';
    final correcta = json['correcta'] as String? ?? '';
    final opciones = (json['opciones'] as List?)?.whereType<String>().toList() ??
        const <String>[];

    // Sin hueco no hay nada que completar, y si la correcta no está entre los
    // botones la frase es imposible de contestar. En los dos casos se descarta
    // en vez de romper la pantalla; un test avisa si pasa.
    if (!frase.contains(hueco) ||
        correcta.isEmpty ||
        !opciones.contains(correcta)) {
      return null;
    }

    return FraseParticella(
      frase: frase,
      correcta: correcta,
      espanol: json['es'] as String? ?? '',
      opciones: opciones,
      explicacion: json['explicacion'] as String? ?? '',
      persona: json['persona'] as String? ?? '',
    );
  }
}

/// Todo lo que trae el JSON de una partícula.
class DatosParticelle {
  const DatosParticelle({required this.version, required this.frases});

  final int version;
  final List<FraseParticella> frases;

  static const vacio = DatosParticelle(version: 0, frases: []);

  static DatosParticelle desdeJson(Map<String, dynamic> json) {
    final frases = <FraseParticella>[];
    final lista = json['frases'];
    if (lista is List) {
      for (final item in lista) {
        if (item is! Map<String, dynamic>) continue;
        final frase = FraseParticella.desdeJson(item);
        if (frase != null) frases.add(frase);
      }
    }

    return DatosParticelle(
      version: json['version'] as int? ?? 0,
      frases: frases,
    );
  }
}
