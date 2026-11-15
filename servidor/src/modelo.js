// El que le pregunta al modelo. Lo único que sabe de Workers AI.
//
// Antes acá vivía un cliente de Gemini con la clave de Google. Ya no: los
// modelos los corre Cloudflare, en la misma cuenta donde vive este worker, y
// no hay ninguna clave de por medio. Ni la app pide una, ni el servidor
// guarda una, ni hay nada que se pueda filtrar.
//
// Cuál modelo contesta es una variable de wrangler.toml. Cambiarlo es cambiar
// un renglón y publicar el servidor: no hace falta tocar la app ni que nadie
// instale un APK nuevo.

/// Cuál se usa si wrangler.toml no dice otra cosa.
export const MODELO_POR_DEFECTO = '@cf/meta/llama-3.3-70b-instruct-fp8-fast';

/// El tope de lo que puede contestar. Las instrucciones piden dos o tres
/// frases, así que con esto sobra; y cuanto más corto, menos cuota se gasta.
const CUANTO_PUEDE_DECIR = 300;

/** Una falla con un motivo que la app sabe mostrar. */
export class FallaDelModelo extends Error {
  constructor(motivo, detalle) {
    super(detalle ?? motivo);
    this.motivo = motivo;
  }
}

/** Le manda la charla al modelo y devuelve lo que contestó.
 *
 * `ia` es el binding de Workers AI. Llega por parámetro y no importado para
 * que atender.js se pueda probar con uno de mentira, sin cuenta y sin gastar
 * neuronas. */
export async function preguntarle(mensajes, ia, modelo = MODELO_POR_DEFECTO) {
  let contestado;
  try {
    contestado = await ia.run(modelo, {
      messages: mensajes,
      max_tokens: CUANTO_PUEDE_DECIR,
    });
  } catch (error) {
    throw new FallaDelModelo(porQue(error), String(error));
  }

  return texto(contestado);
}

/** Qué le pasó, traducido a los motivos que la app sabe mostrar.
 *
 * Workers AI no tiene códigos de estado como una API HTTP: lo que llega es una
 * excepción con un texto. Se mira ese texto, y lo que no se reconoce queda
 * como "la IA no está respondiendo", que es lo que el alumno ve igual. */
function porQue(error) {
  const dice = String(error?.message ?? error).toLowerCase();
  if (dice.includes('capacity') || dice.includes('rate limit')) return 'cuota';
  if (dice.includes('timeout') || dice.includes('timed out')) return 'tardo';
  // 5035 es el que devuelve Cloudflare cuando el modelo pide tarjeta cargada.
  if (dice.includes('5035') || dice.includes('billing')) return 'cuota';
  return 'caido';
}

/** Saca el texto de la respuesta.
 *
 * Va todo chequeado porque una respuesta con otra forma tiene que dar un error
 * entendible y no tirar abajo el servidor. */
function texto(contestado) {
  if (contestado === null || typeof contestado !== 'object') {
    throw new FallaDelModelo('sinRespuesta');
  }

  const dicho = (contestado.response ?? '').trim();
  if (dicho === '') throw new FallaDelModelo('sinRespuesta');
  return dicho;
}
