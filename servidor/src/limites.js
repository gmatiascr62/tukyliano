// Cuántos mensajes lleva cada uno hoy, y cuántos lleva el servidor entero.
//
// Son dos topes y hacen dos cosas distintas:
//
// - El de cada persona reparte: que uno charlando toda la tarde no deje sin
//   nada a los demás.
// - El total es la red de seguridad: si un día pasa algo raro —un error que
//   reintenta solo, alguien abusando— el servidor deja de pedirle a Google en
//   vez de seguir gastando. Es lo único que separa "se gastó la cuota" de
//   "llegó una factura".
//
// Se guarda en D1 y no en KV porque el plan gratis de KV permite mil
// escrituras por día y cada mensaje es una. D1 permite cien mil.
//
// Lo único que se guarda es: quién, qué día, cuántos. Ni las charlas ni lo que
// se dijo.

/** El día de hoy en UTC, que es con el que Cloudflare reinicia sus cuotas. */
export function elDiaDeHoy(ahora = new Date()) {
  return ahora.toISOString().slice(0, 10);
}

/// Con qué nombre se guarda el contador de todo el servidor. Lleva espacios
/// para que no pueda chocar con el identificador de ningún celular.
export const TODOS = '* todos *';

/** Suma uno a los dos contadores y devuelve cómo quedaron.
 *
 * Se suma antes de preguntarle a Gemini, no después: si el pedido falla
 * igual contamos el intento. Es a propósito —un error que se reintenta solo
 * es justo lo que puede vaciar la cuota— y el precio es que un día con
 * muchas fallas gasta tope sin haber hablado.
 */
export async function sumarUno(base, quien, dia = elDiaDeHoy()) {
  const [deEl, deTodos] = await Promise.all([
    unoMas(base, quien, dia),
    unoMas(base, TODOS, dia),
  ]);
  return { suyos: deEl, totales: deTodos };
}

async function unoMas(base, quien, dia) {
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

/** Qué pasa con los topes. Devuelve null si puede seguir, o el motivo si no. */
export function loQueFalla({ suyos, totales }, topes) {
  if (totales > topes.deTodos) return 'topeDelServidor';
  if (suyos > topes.deCadaUno) return 'topeDeLaPersona';
  return null;
}
