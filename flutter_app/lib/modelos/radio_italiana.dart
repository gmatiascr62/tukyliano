/// Una radio italiana en vivo.
///
/// Escuchar radio en vivo es el escalón más alto que hay: italiano nativo, a
/// velocidad real, sin contexto, sin repetición y sin subtítulos. No está acá
/// para entender todo, está para acostumbrar el oído a cómo suena el idioma
/// cuando nadie lo está frenando para vos.
class RadioItaliana {
  const RadioItaliana({
    required this.id,
    required this.nombre,
    required this.que,
    required this.ojo,
    required this.stream,
    required this.sitio,
    required this.sostener,
    required this.quien,
    this.balanceador = '',
  });

  final String id;
  final String nombre;

  /// Qué es, en criollo.
  final String que;

  /// Para qué NO sirve. Va en la pantalla junto con lo otro: una emisora que
  /// promete más de lo que da se abre una vez y no se vuelve a abrir.
  final String ojo;

  /// La dirección del audio en vivo.
  ///
  /// Si hay balanceador, esta es la de respaldo: la que se usa cuando el
  /// balanceador no contesta. Tiene que ser una que funcione sola.
  final String stream;

  /// A quién preguntarle por qué nodo transmite hoy, si la emisora reparte
  /// desde varios. Vacío si transmite siempre desde el mismo lugar.
  ///
  /// Ver DondeSuenaLaRadio: la respuesta hay que pasarla a https.
  final String balanceador;

  final String sitio;

  /// Dónde se la puede ayudar. Estas radios las hacen voluntarios y el audio
  /// que la app reproduce lo pagan ellos.
  final String sostener;

  /// Quién la hace. Va a la vista: es lo mínimo.
  final String quien;

  static RadioItaliana desdeJson(Map<String, dynamic> datos) => RadioItaliana(
        id: datos['id'] as String,
        nombre: datos['nombre'] as String,
        que: datos['que'] as String? ?? '',
        ojo: datos['ojo'] as String? ?? '',
        stream: datos['stream'] as String,
        balanceador: datos['balanceador'] as String? ?? '',
        sitio: datos['sitio'] as String? ?? '',
        sostener: datos['sostener'] as String? ?? '',
        quien: datos['quien'] as String? ?? '',
      );
}
