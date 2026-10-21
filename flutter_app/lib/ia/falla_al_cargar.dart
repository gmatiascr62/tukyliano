/// Cómo se cuenta que el modelo no cargó.
///
/// Esto parece cosmético y no lo es. El mensaje anterior repetía cuatro veces
/// el mismo error en inglés, con la ruta entera del archivo adentro, y lo
/// único nuevo —lo que dijo el motor— quedaba al final, abajo del borde de la
/// pantalla, donde no se podía leer. Un error que no se lee no sirve para
/// nada.
library;

/// Un intento de cargar el modelo y cómo terminó.
typedef Intento = ({String nombre, String motivo});

/// Los errores del motor, que vienen en inglés y anidados, dichos corto.
const Map<String, String> _enCriollo = {
  'Could not load model': 'no pudo abrir el modelo',
  'Could not create context': 'no pudo armar el contexto',
  'Failed to open library': 'no encontró la biblioteca',
  'already exists': 'chocó con un intento anterior',
};

/// De un error anidado y con la ruta entera adentro, lo que se entiende.
String motivoCorto(String crudo) {
  for (final entrada in _enCriollo.entries) {
    if (crudo.contains(entrada.key)) return entrada.value;
  }

  // Lo que quede: sin el nombre de la clase, sin la ruta y sin paréntesis
  // sueltos, que es lo que lo hace ilegible.
  final limpio = crudo
      .replaceAll('LlamaException:', '')
      .replaceAll(RegExp(r'\s*at /\S+'), '')
      .replaceAll(RegExp(r'[()]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return limpio.length <= 90 ? limpio : '${limpio.substring(0, 90)}…';
}

/// El mensaje que se ve en la pantalla cuando el modelo no carga.
///
/// Primero lo que dijo el motor, que es lo único que cambia de un celular a
/// otro; después el archivo, para sacar esa duda; y al final qué se intentó.
String mensajeDeFalla({
  required List<Intento> intentos,
  String dicho = '',
  String archivo = '',
}) {
  final partes = <String>['No se pudo cargar el modelo.'];

  partes.add(dicho.isEmpty ? 'El motor no dijo por qué.' : 'Dice: $dicho');

  if (archivo.isNotEmpty) partes.add('El archivo: $archivo.');

  final motivos = intentos.map((intento) => motivoCorto(intento.motivo)).toSet();
  final cuales = intentos.map((intento) => intento.nombre).join(', ');

  if (intentos.isEmpty) {
    // No debería pasar, pero un mensaje a medias es peor que uno corto.
  } else if (motivos.length == 1) {
    partes.add(intentos.length == 1
        ? 'Probé con $cuales: ${motivos.first}.'
        : 'Probé de ${intentos.length} formas ($cuales) y en todas '
            '${motivos.first}.');
  } else {
    partes.add('Probé así: ${intentos.map(
          (intento) => '${intento.nombre}, ${motivoCorto(intento.motivo)}',
        ).join('; ')}.');
  }

  return partes.join(' ');
}
