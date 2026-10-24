// Arma el pedido que se le manda a Gemini a partir de la charla que mandó la
// app.
//
// La app manda la charla tal cual la ve el alumno: el saludo con el que
// arrancó y los mensajes que siguieron. Todo lo que es "cómo se le habla al
// modelo" —las instrucciones, el recordatorio de las traducciones, el formato
// de los turnos— vive acá.

import { promptDeTuky } from './prompt.js';

/// Un pedido de traducción cerrado: '#manteca#'. Una almohadilla sola no
/// cuenta, así que mientras se escribe '#man' todavía no es un pedido.
const PEDIDO_CERRADO = /#([^#]+)#/g;

/// Cualquier cosa que no sea una letra: espacios, signos, números.
const NO_ES_LETRA = /[^\p{L}]/gu;

/** Lo que se pidió traducir: de 'quiero #manteca# y #pan#' saca ['manteca', 'pan']. */
export function pedidosDeTraduccion(texto) {
  return [...texto.matchAll(PEDIDO_CERRADO)]
    .map((p) => p[1].trim())
    .filter((p) => p.length > 0);
}

/** True cuando el mensaje es solo un pedido de traducción, sin nada escrito
 * afuera de las almohadillas.
 *
 * Es la diferencia entre las dos formas de usar el chat: '#manteca#' es ir al
 * diccionario y se contesta solo con la traducción, mientras que 'mi serve la
 * #manteca#' es charlar y ahí la charla sigue. */
export function esSoloTraduccion(mensaje) {
  if (pedidosDeTraduccion(mensaje).length === 0) return false;
  const afuera = mensaje.replace(PEDIDO_CERRADO, '');
  return afuera.replace(NO_ES_LETRA, '') === '';
}

/** El mensaje del alumno con el recordatorio de las traducciones, si hace falta.
 *
 * El recordatorio va solo en el último mensaje: en los viejos ya no sirve de
 * nada y ensuciaría el historial. */
export function textoParaLaIa(mensaje) {
  const pedidos = pedidosDeTraduccion(mensaje);
  if (pedidos.length === 0) return mensaje;

  const ejemplos = pedidos.map((p) => `#${p}# = #(traducción)#`).join(', ');
  const direccion =
    'Si está en español traducilo al italiano; si está en italiano traducilo ' +
    'al español. Nunca devuelvas la misma palabra.';

  if (esSoloTraduccion(mensaje)) {
    return (
      `${mensaje}\n\n` +
      '(Esto es solo un pedido de traducción, no es charla. Contestá ' +
      `únicamente ${ejemplos}, un renglón por pedido, y nada más: sin saludos, ` +
      `sin preguntas y sin comentarios. ${direccion})`
    );
  }

  return (
    `${mensaje}\n\n` +
    '(Recordá: lo que está entre # es un pedido de traducción. Empezá tu ' +
    `respuesta con ${ejemplos}, un renglón por pedido, y después seguí la ` +
    `charla en italiano. ${direccion})`
  );
}

/** Un turno en el formato que espera la API: 'user' es el alumno, 'model' es
 * Tuky. */
export function turno(rol, texto) {
  return { role: rol, parts: [{ text: texto }] };
}

/** La charla entera, lista para mandársela a Gemini.
 *
 * `saludo` es con el que arrancó la charla, que la app sortea sola para no
 * gastar un pedido. `mensajes` son los que vinieron después, cada uno con
 * `quien` ('yo' o 'ia') y `texto`. */
export function contenidos({ saludo, mensajes }) {
  const turnos = [turno('user', promptDeTuky), turno('model', saludo)];

  mensajes.forEach((mensaje, i) => {
    const mio = mensaje.quien === 'yo';
    const ultimo = i === mensajes.length - 1;
    turnos.push(
      turno(
        mio ? 'user' : 'model',
        mio && ultimo ? textoParaLaIa(mensaje.texto) : mensaje.texto,
      ),
    );
  });

  return turnos;
}
