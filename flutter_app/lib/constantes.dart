/// JSON en GitHub que se chequea para ver si hay verbos nuevos.
/// Es el mismo que usa la app Kivy: el repo de datos no se toca.
const String urlRemoto =
    'https://raw.githubusercontent.com/gmatiascr62/tukylingo_repo/main/data.json';

/// Copia de respaldo empaquetada con la app.
const String assetVerbos = 'assets/verbos.json';

/// Frases escritas a mano que vienen con la app. Es el respaldo para el
/// primer arranque y para cuando no hay internet: la lista al día se baja de
/// GitHub.
const String assetFrases = 'assets/frases.json';

/// Frases en GitHub. Van en un archivo aparte de los verbos para poder
/// agregarlas sin publicar un APK nuevo.
const String urlFrasesRemoto =
    'https://raw.githubusercontent.com/gmatiascr62/tukylingo_repo/main/frases.json';

/// Copia escribible de las frases en el celular.
const String archivoFrasesLocal = 'frases.json';

/// Sustantivos y reglas de los artículos que vienen con la app.
const String assetArticoli = 'assets/articoli.json';

/// Los mismos, en GitHub: agregar palabras no necesita un APK nuevo.
const String urlArticoliRemoto =
    'https://raw.githubusercontent.com/gmatiascr62/tukylingo_repo/main/articoli.json';

/// Copia escribible de los artículos en el celular.
const String archivoArticoliLocal = 'articoli.json';

/// Frases con un hueco para practicar las preposiciones.
const String assetPreposizioni = 'assets/preposizioni.json';

/// Las mismas, en GitHub: agregar frases no necesita un APK nuevo.
const String urlPreposizioniRemoto =
    'https://raw.githubusercontent.com/gmatiascr62/tukylingo_repo/main/preposizioni.json';

/// Copia escribible de las preposiciones en el celular.
const String archivoPreposizioniLocal = 'preposizioni.json';

/// Cuentos para leer que vienen con la app.
const String assetRacconti = 'assets/racconti.json';

/// Los mismos, en GitHub: agregar cuentos no necesita un APK nuevo.
const String urlRaccontiRemoto =
    'https://raw.githubusercontent.com/gmatiascr62/tukylingo_repo/main/racconti.json';

/// Copia escribible de los cuentos en el celular.
const String archivoRaccontiLocal = 'racconti.json';

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
