// El cliente de Gemini. Es lo mismo que tenía la app, movido acá.
//
// La diferencia que importa: la clave ya no viaja en ningún celular. Vive en
// un secreto de Cloudflare y solo este archivo la ve.

/// Modelo "lite" a propósito: gemini-2.5-flash tiene una cuota gratis de solo
/// 20 pedidos por día por proyecto, que se agota enseguida. El lite tiene una
/// cuota aparte mucho más alta.
export const modeloGemini = 'gemini-flash-lite-latest';

const URL_GEMINI =
  `https://generativelanguage.googleapis.com/v1beta/models/${modeloGemini}:generateContent`;

/// Cuánto se espera antes de dar el pedido por perdido. Más que esto, el
/// alumno ya cerró la app.
const PACIENCIA_MS = 25_000;

/** Una falla con un motivo que la app sabe mostrar. */
export class FallaDeGemini extends Error {
  constructor(motivo, detalle) {
    super(detalle ?? motivo);
    this.motivo = motivo;
  }
}

/** Le manda la charla a Gemini y devuelve lo que contestó.
 *
 * `traer` es fetch; se pasa aparte para poder probar esto sin internet. */
export async function preguntarle(contenidos, clave, traer = fetch) {
  const corte = AbortSignal.timeout(PACIENCIA_MS);

  let respuesta;
  try {
    respuesta = await traer(`${URL_GEMINI}?key=${encodeURIComponent(clave)}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
      body: JSON.stringify({ contents: contenidos }),
      signal: corte,
    });
  } catch (error) {
    // Se cayó la conexión o se acabó la paciencia: para el alumno es lo mismo.
    throw new FallaDeGemini('tardo', String(error));
  }

  if (respuesta.status === 429) throw new FallaDeGemini('cuota');
  if (respuesta.status === 403) {
    throw new FallaDeGemini('clave', await respuesta.text());
  }

  // Un 400 puede ser la clave o un pedido mal armado. Se distingue por el
  // mensaje: si no, un error nuestro quedaría anotado como "la clave no sirve"
  // y buscaríamos el problema donde no está.
  if (respuesta.status === 400) {
    const cuerpo = await respuesta.text();
    const mayusculas = cuerpo.toUpperCase();
    if (mayusculas.includes('API_KEY') || mayusculas.includes('API KEY')) {
      throw new FallaDeGemini('clave', cuerpo);
    }
    throw new FallaDeGemini('pedido', cuerpo);
  }

  if (!respuesta.ok) {
    throw new FallaDeGemini('caido', `Gemini respondió ${respuesta.status}`);
  }

  return texto(await respuesta.json());
}

/** Saca el texto de la respuesta.
 *
 * Va todo chequeado porque un JSON distinto al esperado tiene que dar un error
 * entendible y no tirar abajo el servidor. */
function texto(datos) {
  if (datos === null || typeof datos !== 'object') {
    throw new FallaDeGemini('sinRespuesta');
  }

  const candidatos = datos.candidates;
  if (!Array.isArray(candidatos) || candidatos.length === 0) {
    throw new FallaDeGemini('sinRespuesta');
  }

  const partes = candidatos[0]?.content?.parts;
  if (!Array.isArray(partes) || partes.length === 0) {
    throw new FallaDeGemini('sinRespuesta');
  }

  const dicho = (partes[0]?.text ?? '').trim();
  if (dicho === '') throw new FallaDeGemini('sinRespuesta');
  return dicho;
}
