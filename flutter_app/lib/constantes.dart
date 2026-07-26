/// JSON en GitHub que se chequea para ver si hay verbos nuevos.
/// Es el mismo que usa la app Kivy: el repo de datos no se toca.
const String urlRemoto =
    'https://raw.githubusercontent.com/gmatiascr62/tukylingo_repo/main/data.json';

/// Copia de respaldo empaquetada con la app.
const String assetVerbos = 'assets/verbos.json';

/// Archivo escribible donde se guardan los verbos ya actualizados.
const String archivoVerbosLocal = 'verbos_local.json';

/// Tiempos verbales que se pueden practicar.
const List<String> tiemposDisponibles = [
  'presente',
  'passato_prossimo',
  'imperfetto',
  'futuro_semplice',
];

const Map<String, String> etiquetasTiempo = {
  'presente': 'presente',
  'passato_prossimo': 'passato prossimo',
  'imperfetto': 'imperfetto',
  'futuro_semplice': 'futuro semplice',
};
