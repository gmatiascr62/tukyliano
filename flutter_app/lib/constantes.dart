/// JSON en GitHub que se chequea para ver si hay verbos nuevos.
/// Es el mismo que usa la app Kivy: el repo de datos no se toca.
const String urlRemoto =
    'https://raw.githubusercontent.com/gmatiascr62/tukylingo_repo/main/data.json';

/// Copia de respaldo empaquetada con la app.
const String assetVerbos = 'assets/verbos.json';

/// Frases escritas a mano que vienen con la app, para no depender de la IA
/// en cada tirada.
const String assetFrases = 'assets/frases.json';

/// Archivo escribible donde se guardan los verbos ya actualizados.
const String archivoVerbosLocal = 'verbos_local.json';

/// El gerundio no tiene personas: es una sola forma por verbo. Se lo trata
/// como un tiempo más con esta persona única, para no complicar el resto.
const String tiempoGerundio = 'gerundio';
const String personaGerundio = '-';

/// Tiempos verbales que se pueden practicar.
const List<String> tiemposDisponibles = [
  'presente',
  'passato_prossimo',
  'imperfetto',
  'futuro_semplice',
  tiempoGerundio,
];

const Map<String, String> etiquetasTiempo = {
  'presente': 'presente',
  'passato_prossimo': 'passato prossimo',
  'imperfetto': 'imperfetto',
  'futuro_semplice': 'futuro semplice',
  tiempoGerundio: 'gerundio',
};
