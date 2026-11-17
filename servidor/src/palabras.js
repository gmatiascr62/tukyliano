// El diccionario de respaldo: qué pasa cuando la app no sabe una palabra.
//
// La idea es de Matías y es la buena: preguntarle a la IA una sola vez por
// palabra en toda la historia del servidor, guardarla, y que a partir de ahí
// cualquiera que busque esa misma palabra la reciba de la base.
//
//     1. ¿está en el diccionario del celular?  → gratis, sin internet
//     2. ¿está en la base del servidor?        → gratis, sin IA
//     3. recién ahí se le pregunta a la IA     → y se guarda
//
// El segundo que busque "lumicino" no gasta nada. Y cada tanto se bajan las
// más buscadas y entran al diccionario que viaja en el APK, con lo que dejan
// de costar hasta la ida al servidor.
//
// El tope es aparte del tope del chat, y es mucho más alto, porque son dos
// cosas de costos distintos: una charla son párrafos y esto son tres
// palabras. Pero existe igual: sin tope, alguien con el APK y un script le
// vacía la cuota de Gemini en una tarde.

import { loQueDijo } from './gemini.js';
import { elDiaDeHoy, TODOS } from './limites.js';
import { queSalioMal } from './respuestas.js';

/// Cuántas palabras nuevas por día. Las que ya están en la base no cuentan:
/// esas no le cuestan nada a nadie.
export const TOPES_POR_DEFECTO = { deCadaUno: 120, deTodos: 3000 };

/// Hasta acá se acepta una palabra. Más largo que esto no es una palabra que
/// alguien tocó en la pantalla.
const LARGO_MAXIMO = 40;

/** Deja el pedido listo, o null si no se entiende. */
export function loQueMando(cuerpo) {
  if (cuerpo === null || typeof cuerpo !== 'object') return null;

  const { palabra, donde, codigo, quien } = cuerpo;
  if (typeof palabra !== 'string') return null;
  const limpia = normalizar(palabra);
  if (!limpia || limpia.length > LARGO_MAXIMO) return null;
  if (typeof quien !== 'string' || quien.trim() === '') return null;

  return {
    palabra: limpia,
    // El renglón es opcional y se usa para desambiguar: "lumicino" solo es
    // "lucecita", y en "ridotto al lumicino" es "en las últimas".
    donde: typeof donde === 'string' ? donde.slice(0, 200).trim() : '',
    codigo,
    quien: quien.trim(),
  };
}

/** La palabra como la guarda el diccionario de la app: minúscula, sin tildes.
 *
 * Tiene que coincidir con lo que hace la app, porque si no "Lumicino" y
 * "lumicino" serían dos filas en la base y dos preguntas a la IA por la misma
 * palabra.
 */
export function normalizar(palabra) {
  return palabra
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9']/g, '')
    .trim();
}

/** Busca en la base. Null si no está. */
export async function laQueYaEsta(base, palabra) {
  const fila = await base
    .prepare('SELECT es, base FROM palabras WHERE palabra = ?')
    .bind(palabra)
    .first();
  if (!fila) return null;
  return { es: String(fila.es).split(','), base: fila.base || '' };
}

/** La guarda, o le suma una visita si ya estaba. */
export async function guardar(base, palabra, que, dia = elDiaDeHoy()) {
  await base
    .prepare(
      `INSERT INTO palabras (palabra, es, base, cuando, cuantas)
       VALUES (?, ?, ?, ?, 1)
       ON CONFLICT (palabra) DO UPDATE SET cuantas = cuantas + 1`,
    )
    .bind(palabra, que.es.join(','), que.base || null, dia)
    .run();
}

/** Le suma una visita a una que ya estaba, para saber qué se busca más. */
export async function unaVisitaMas(base, palabra) {
  await base
    .prepare('UPDATE palabras SET cuantas = cuantas + 1 WHERE palabra = ?')
    .bind(palabra)
    .run();
}

/** Cuántas preguntas a la IA van hoy, sumando esta. */
export async function sumarUnaPregunta(base, quien, dia = elDiaDeHoy()) {
  const comoSiFuera = (nombre) => `palabra ${nombre}`;
  const [suyos, totales] = await Promise.all([
    unaMas(base, comoSiFuera(quien), dia),
    unaMas(base, comoSiFuera(TODOS), dia),
  ]);
  return { suyos, totales };
}

async function unaMas(base, quien, dia) {
  const fila = await base
    .prepare(
      `INSERT INTO mensajes (quien, dia, cuantos) VALUES (?, ?, 1)
       ON CONFLICT (quien, dia) DO UPDATE SET cuantos = cuantos + 1
       RETURNING cuantos`,
    )
    .bind(quien, dia)
    .first();
  return fila?.cuantos ?? 0;
}

/** Atiende un pedido de traducción. */
export async function atenderLaPalabra(cuerpo, afuera) {
  const {
    base, clave, permitidos, topes, ahora, seguirDespues,
    cuantoEspera = CUANTO_ESPERA_LA_PERSONA,
  } = afuera;

  const pedido = loQueMando(cuerpo);
  if (pedido === null) return queSalioMal('pedidoRaro');

  if (!puedeEntrar(pedido.codigo, permitidos)) {
    const vacio = (pedido.codigo ?? '').trim() === '';
    return queSalioMal(vacio ? 'sinCodigo' : 'codigoQueNoEs');
  }

  // 1. La base. Esto es lo que hace que la idea valga: a partir de la
  //    segunda vez que alguien busca una palabra, no cuesta nada.
  const guardada = await laQueYaEsta(base, pedido.palabra);
  if (guardada) {
    await unaVisitaMas(base, pedido.palabra);
    return laRespuesta(pedido.palabra, guardada, 'base');
  }

  // 2. Recién ahora la IA, y recién ahora se gasta tope.
  const dia = elDiaDeHoy(ahora);
  const cuantas = await sumarUnaPregunta(base, pedido.quien, dia);
  if (cuantas.totales > topes.deTodos) return queSalioMal('topeDelServidor');
  if (cuantas.suyos > topes.deCadaUno) return queSalioMal('topeDeLaPersona');

  // 3. La IA. Pero el que preguntó no espera lo que tarde: espera lo que
  //    aguanta mirando la pantalla, y después se va con un "no está".
  //
  //    La demora de Gemini es traicionera: la mediana es de 2,7 segundos,
  //    pero una de cada siete llamadas tarda más de un minuto. Si se
  //    cortara ahí, esa palabra se perdería, y el próximo que la busque
  //    jugaría a la misma lotería.
  //
  //    Así que la pregunta sigue sola, aunque la respuesta ya se haya ido.
  //    El primero que buscó "lumicino" un día lento se queda sin ella; el
  //    segundo la recibe de la base al instante. La palabra entra igual.
  const laPregunta = (async () => {
    const { que, porQue } = await loQueDijo(pedido.palabra, pedido.donde,
                                            clave);
    if (que) await guardar(base, pedido.palabra, que, dia);
    return { que, porQue };
  })();

  if (seguirDespues) seguirDespues(laPregunta);

  const salio = await loQuePrimeroLlegue(laPregunta, cuantoEspera);
  if (salio?.que) return laRespuesta(pedido.palabra, salio.que, 'ia');

  // Por qué no hay respuesta, y no un "tardó" para todo.
  //
  // Antes esto decía siempre 'tardo', y era mentira en casi todos los
  // casos: Gemini puede contestar que no en medio segundo. El día que
  // Google suspendió la cuenta por una factura impaga —un 403 instantáneo
  // en cada pedido— el servidor seguía diciendo "tardó", y para encontrar
  // la causa hubo que llamar a Gemini a mano desde afuera.
  //
  // Ahora 'tardo' significa que de verdad se acabó el tiempo, y cualquier
  // otra cosa —el código HTTP que devolvió Google, 'sinClave', 'red'—
  // viaja tal cual. No se muestra en pantalla: la app sigue diciendo que
  // no está. Pero queda en la respuesta, que es donde se mira cuando algo
  // no anda.
  return noLaSabe(pedido.palabra, salio?.porQue || 'tardo');
}

/// Cuánto aguanta mirando la pantalla el que tocó una palabra. Pasado
/// esto prefiere un "no está" a seguir esperando.
export const CUANTO_ESPERA_LA_PERSONA = 7000;

/** Lo que conteste la pregunta, o null si se pasó de tiempo.
 *
 * No cancela nada: la pregunta sigue su camino y guarda lo que llegue.
 */
function loQuePrimeroLlegue(laPregunta, cuanto = CUANTO_ESPERA_LA_PERSONA) {
  return Promise.race([
    laPregunta.catch(() => null),
    new Promise((listo) => setTimeout(() => listo(null), cuanto)),
  ]);
}

/** Si puede preguntar. Mismo criterio que el chat. */
export function puedeEntrar(codigo, permitidos) {
  if (permitidos.length === 0) return true;
  return permitidos.includes((codigo ?? '').trim());
}

/// Que no esté no es un error: es una respuesta. La app muestra lo mismo
/// que mostraba antes de que este servidor existiera.
function noLaSabe(palabra, porQue = '') {
  return Response.json({ palabra, es: [], base: '', de: 'nadie', porQue });
}

function laRespuesta(palabra, que, de) {
  return Response.json({ palabra, es: que.es, base: que.base || '', de });
}
