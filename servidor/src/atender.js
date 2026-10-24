// Qué hace el servidor con cada pedido.
//
// Está separado de index.js a propósito: acá no se nombra Cloudflare ni una
// vez. Todo lo de afuera —la base, la clave, quién puede entrar, el reloj—
// llega por parámetro. Así esto se prueba entero con un `node --test`, sin
// cuenta, sin internet y sin gastar cuota.
//
// Y si algún día hay que mudar el servidor a otro lado, lo que cambia es
// index.js. Esto queda igual.

import { contenidos } from './charla.js';
import { preguntarle, FallaDeGemini } from './gemini.js';
import { elDiaDeHoy, loQueFalla, sumarUno } from './limites.js';
import { queSalioMal, salioBien } from './respuestas.js';

/** Si el código que mandaron sirve.
 *
 * Con la lista vacía entra cualquiera. Es así para poder probar el servidor
 * antes de tener a quién repartirle códigos, pero con el APK publicado deja
 * la puerta abierta: ver el README. */
export function puedeEntrar(codigo, permitidos) {
  if (permitidos.length === 0) return true;
  return permitidos.includes((codigo ?? '').trim());
}

/** Lo que la app tiene que mandar, chequeado.
 *
 * Devuelve el pedido ya limpio, o null si no se entiende. Un pedido mal armado
 * no puede llegar hasta Gemini: sería gastar cuota en algo que no va a servir. */
export function loQueMando(cuerpo) {
  if (cuerpo === null || typeof cuerpo !== 'object') return null;

  const { quien, codigo, saludo, mensajes } = cuerpo;
  if (typeof quien !== 'string' || quien.trim() === '') return null;
  if (typeof saludo !== 'string' || saludo.trim() === '') return null;
  if (!Array.isArray(mensajes) || mensajes.length === 0) return null;

  const limpios = [];
  for (const mensaje of mensajes) {
    if (mensaje === null || typeof mensaje !== 'object') return null;
    const { quien: deQuien, texto } = mensaje;
    if (deQuien !== 'yo' && deQuien !== 'ia') return null;
    if (typeof texto !== 'string' || texto.trim() === '') return null;
    limpios.push({ quien: deQuien, texto });
  }

  // El último tiene que ser del alumno: si no, no hay nada que contestar.
  if (limpios[limpios.length - 1].quien !== 'yo') return null;

  return { quien: quien.trim(), codigo, saludo, mensajes: limpios };
}

/** Atiende un pedido de charla. */
export async function atenderLaCharla(cuerpo, afuera) {
  const { base, clave, permitidos, topes, traer, ahora } = afuera;

  const pedido = loQueMando(cuerpo);
  if (pedido === null) return queSalioMal('pedidoRaro');

  if (!puedeEntrar(pedido.codigo, permitidos)) {
    const vacio = (pedido.codigo ?? '').trim() === '';
    return queSalioMal(vacio ? 'sinCodigo' : 'codigoQueNoEs');
  }

  const cuantos = await sumarUno(base, pedido.quien, elDiaDeHoy(ahora));
  const pasado = loQueFalla(cuantos, topes);
  if (pasado !== null) return queSalioMal(pasado);

  try {
    const dicho = await preguntarle(contenidos(pedido), clave, traer);
    return salioBien(dicho);
  } catch (error) {
    if (error instanceof FallaDeGemini) return queSalioMal(error.motivo);
    throw error;
  }
}
